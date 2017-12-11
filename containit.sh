#!/usr/bin/env bash

# ContainIt - The easy button for running commands in containers
#             https://github.com/unboundedsystems/containit
#
# Copyright (c) 2017 Unbounded Systems LLC

#
# For info on using ContainIt to run your commands in containers, see
# README.md
#


###################################################################
# Utility functions
###################################################################

# Quote and escape each word argument
quote() {
    printf "%q " "$@"
}

# Returns the absolute path to a file, without any sym links.
# OSX and some other *nix platforms do not have realpath by default
realPath() {
    unset -v CDPATH
    local BASE="$(basename "$1")"
    pushd "$(dirname "$1")" >/dev/null
    local LINK="$(readlink "$BASE")"
    while [ "$LINK" ]; do
        cd "$(dirname "$LINK")"
        LINK="$(readlink "$BASE")"
    done
    REALPATH="$(pwd -P)"

    case $BASE in
        .)
            # Don't append BASE to the path
            ;;
        ..)
            # Remove one directory from the path
            REALPATH="$(dirname "$REALPATH")"
            ;;
        *)
            REALPATH="${REALPATH}/${BASE}"
            ;;
    esac
    popd >/dev/null
    echo "$REALPATH"
}

# Returns the relative path from $1 to $2
# Both arguments MUST be absolute paths (beginning with /)
relativePath() {
  local source="$1"
  local target="$2"

  local commonPart="$source"
  local result=""

  while [[ "${target#$commonPart}" == "${target}" ]]; do
    # no match, means that candidate common part is not correct
    # go up one level (reduce common part)
    commonPart="$(dirname "$commonPart")"
    # and record that we went back, with correct / handling
    if [[ -z "$result" ]]; then
      result=".."
    else
      result="../$result"
    fi
  done

  if [[ "$commonPart" == "/" ]]; then
    # special case for root (no common path)
    result="$result/"
  fi

  # since we now have identified the common part,
  # compute the non-common part
  local forwardPart="${target#$commonPart}"

  # and now stick all parts together
  if [[ -n "$result" ]] && [[ -n "$forwardPart" ]]; then
    result="$result$forwardPart"
  elif [[ -n "$forwardPart" ]]; then
    # extra slash removal
    result="${forwardPart:1}"
  fi

  echo "$result"
}


# The root of the working directory tree inside the container.
# PROJECT_ROOT outside the container maps to CTR_PROJECT_ROOT inside the
# container.
CTR_PROJECT_ROOT=/src

# If IMAGE is already set in the environment, use that as the docker image.
# If not, use the default below (alpine:latest)
DOCKER_IMAGE="${IMAGE:-alpine:latest}"

# The command to execute in the container is the command "name" we were called
# with. The intended use is for soft links to point to this file with names
# like "npm". That would execute npm inside the container.
EXEC_CMD="$(basename "$0")"

BIN_DIR="$(realPath "$(dirname "$0")")"
PROJECT_ROOT="$(realPath "${BIN_DIR}/..")"
WORK_DIR="${CTR_PROJECT_ROOT}/$(relativePath "${PROJECT_ROOT}" "${PWD}")"

# Properly quote any command line arguments
if [ $# -gt 0 ]; then
    ARGS=$(quote "$@")
else
    ARGS=
fi

# Linux treats PID 1 (which will be the first PID in a container) specially.
# Some signals which typically have a default action of terminate
# (like SIGINT), are ignored by default, unless the process installs a signal
# handler. So the wrapper script below that runs inside the container as PID 1
# installs signal handlers (via the shell 'trap' command), then propagates
# signals to the child process.
#
# But, the shell doesn't execute a trap handler until a foreground command
# completes. So we can't run the command in the foreground because long-running
# commands wouldn't get signals promptly. However, running in the background
# causes two different issues:
#  - The shell sets stdin for the background process to /dev/null, so we
#    must make a copy of the shell's stdin file descriptor and then use that
#    to redirect into the background process stdin.
#  - The shell always blocks SIGINT and SIGQUIT for a background process, so
#    when the shell receives those, we actually send the child SIGTERM, which
#    is not blocked.
WRAPPER=$(cat <<ENDWRAPPER
child=0
sig_handler() {
    sig_send=\$1
    code=\$2
    if [ \$child -ne 0 ]; then
        kill -\$sig_send \$child
        wait \$child
    fi
    exit \$code
}
trap 'sig_handler HUP 129' HUP
trap 'sig_handler TERM 130' INT
trap 'sig_handler TERM 131' QUIT
trap 'sig_handler TERM 143' TERM

# Move shell stdin to fd 3
exec 3<&0 0<&-

PATH=\${PATH}:"${CTR_ADD_PATH}"
export PATH
"$EXEC_CMD" $ARGS <&3 &
child=\$!
wait \$child
ENDWRAPPER
)

DOCKER_ARGS=(-i --rm -w "${WORK_DIR}" "-v${PROJECT_ROOT}:${CTR_PROJECT_ROOT}")

# Unset NPM_CONFIG_LOGLEVEL that the official node container sets so any
# .npmrc log level settings can take effect if desired
DOCKER_ARGS+=(-e NPM_CONFIG_LOGLEVEL)

# If stdin is a TTY, have docker allocate a PTY with -t
if [ -t 0 ]; then
    DOCKER_ARGS+=(-t)
fi

exec docker run "${DOCKER_ARGS[@]}" ${N8_ARGS:-} "${DOCKER_IMAGE}" sh -c "${WRAPPER}"
