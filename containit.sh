#!/usr/bin/env bash
#
# ContainIt container wrapper script
#
# Copyright (c) 2017 Unbounded Systems LLC

# The working directory inside the container
WORKDIR=/src

# The docker image to run
IMAGE=node:8.9.1

# The command to execute in the container is the command "name" we were called
# with. The intended use is for soft links to point to this file with names
# like "npm". That would execute npm inside the container.
EXEC_CMD=$(basename $0)


# Quote and escape each word argument
quote() {
    printf "%q " "$@"
}

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

"$EXEC_CMD" $ARGS <&3 &
child=\$!
wait \$child
ENDWRAPPER
)


# Set the path explicitly. Include node_modules/.bin. So that way a soft link
# to this file called "gulp" will execute the gulp in node_modules/.bin
CTR_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${WORKDIR}/node_modules/.bin"

DOCKER_ARGS=(-i --rm -w "${WORKDIR}" "-v${PWD}:${WORKDIR}" -e "PATH=${CTR_PATH}")

# Unset NPM_CONFIG_LOGLEVEL that the official node container sets so any
# .npmrc log level settings can take effect if desired
DOCKER_ARGS+=(-e NPM_CONFIG_LOGLEVEL)

# If stdin is a TTY, have docker allocate a PTY with -t
if [ -t 0 ]; then
    DOCKER_ARGS+=(-t)
fi

exec docker run "${DOCKER_ARGS[@]}" ${N8_ARGS:-} "${IMAGE}" sh -c "$WRAPPER"
