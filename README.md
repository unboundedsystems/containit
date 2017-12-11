# ContainIt
The easy button for running commands in containers.

[ContainIt on GitHub](https://github.com/unboundedsystems/containit)

ContainIt is designed to make it easy to run commands in containers
instead of just running the native command.  This makes it much easier
to get the right versions of build and deployment tools, work with
different command versions, and commands that don't have native
packages on the host operating system.

## QuickStart
To setup a directory hierarchy to use ContainIt to run commands in a container, do the following:
```
$ cd top-level
# Clone into the directory, or create a git submodule if top-level is a repo
$ git clone https://github.com/unboundedsystems/containit
$ mkdir bin
$ cat > bin/command-that-describes-my-container <<END
#!/usr/bin/env bash
IMAGE="my-container-image:my-container-image-tag"
BIN_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
. "\${BIN_DIR}/../containit/containit.sh"
END
$ chmod 755 bin/command-that-describes-my-container
```

Now, any command can be run inside `my-container-image` by just
creating a symlink `bin/command-that-describes-my-container`.  For
example, to run `bash` inside the container:
```
$ ln -s command-that-describes-my-container bin/bash
```
Running `./bin/bash` will run bash inside a container created from
`my-container-image`.  Once `bash` exits, the container will be
destroyed.

Within the container, top-level will be mounted at `/src`.  The only
caveat is that you must run any linked command from a sub-directory of
`top-level`.  So, `../../bin/bash` from within some sub-directory tree
of top-level will work, but `/path/to/top-level` from, say `/`, will not
work.

## Node.js Project Example

To setup a directory called my-project to use the latest Node.js version 8 to
run npm, node, and anything from `$(npm bin)/...`, do the following:
```
$ cd my-project
$ git clone https://github.com/unboundedsystems/containit
$ mkdir bin
$ cat > bin/node <<END
#!/usr/bin/env bash
IMAGE="node:8"
CTR_ADD_PATH="/src/node_modules/.bin"
BIN_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
. "\${BIN_DIR}/../containit/containit.sh"
END
```

Now, you can initialize your package.json with the correct `npm` by doing:
```
$ ./bin/npm init
```

You can start interactive node by doing:
```
$ ./bin/node
```

And so on.

## Options

ContainIt supports a few other options to customize behavior and
location of files.  See `command` in this repository for more
discussion, and look at the source of `containit.sh` for more details.

## Caveats

`containit.sh` only works when a sourcing or linking script is run from
a directory one-level up from the command being invoked (`top-level`
in the example above) because of how it calculates what to mount as
`/src`.

`containit.sh` attempts to handle Docker signal issues by wrapping the
command that will executed inside the container with a shell script to
forward appropriate signals to the executed command.  However, some
behavior will stil vary from native shell execution.  Pull requests to
address any shortcomings are welcome.

`containit.sh` does not attempt change docker's behavior to split
various output file descriptors (stdout, and stderr being the most
common) to support shell redirects of these streams to different
files.  Again, a pull request addressing this would be most welcome.

For example, the following will not work:
```
$ ./bin/node index.js 2>/dev/null 1>myout
```
In this case stderr and stdout output will end up in `myout` because
ContainIt will add the `-t` flag to `docker run` which loses the
distinction between stderr and stdout.
