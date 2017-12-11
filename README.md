# ContainIt
The easy button for running commands in containers.

[ContainIt on GitHub](https://github.com/unboundedsystems/containit)

Are you tired of having to ensure that you have the correct versions of all
your dev tools installed on every system where you use them? And what about
when OLDER versions of your source code need OLDER tools? And how do you
keep track of which tool versions are needed alongside your source code?

The obvious answer is: use containers. But that's such a pain...until now!

```console
~/exampleproj$ git checkout latest
Switched to branch 'latest'

~/exampleproj$ bin/node --version
v9.2.0

~/exampleproj$ git checkout really_old_version
Switched to branch 'really_old_version'

~/exampleproj$ bin/node --version
v4.8.6
```

# Quick Start
Let's use an example project that we'll creatively call `exampleproj`.
Although it could be any kind of project, we'll say it's a Node.js NPM
module just to show a few specifics.

So for `exampleproj`, we want to be able to run specific versions of these
executables:
* npm
* node
* gulp
* bash (for occasional troubleshooting and poking around in the container)

(For the completed example directory, look in the `exampleproj` directory).

Let's get started!

1.  First, identify your `PROJECT_ROOT` directory. This is the top level
    directory that you wish to have available inside the container. It's
    typically the root of your source code project.
   
    In our example, `PROJECT_ROOT` will be `~/exampleproj`.

2.  Create a `BIN_DIR` directory that is a child of `PROJECT_ROOT` where
    executables will go. A typical name for this directory would be
    `PROJECT_ROOT/bin`. You can also use an already existing directory, but
    it MUST be exactly one level below `PROJECT_ROOT`.

    In our example, `BIN_DIR` is `~/exampleproj/bin`.
    ```console
    mkdir ~/exampleproj/bin
    ```

3.  Put the script `containit.sh` somewhere convenient. You only need one copy
    of it accessible for any number of different projects and/or containers
    that you want to use. However, you may wish to keep it under source
    control, either as a clone of the ContainIt repo or in your project.

    For our example, we'll choose to make a copy of it and put it in the
    `BIN_DIR` for our project so it's under source control along with the
    rest of the project.
    ```console
    cp ./containit.sh ~/exampleproj/bin
    ```

4.  Copy the script `command` to `BIN_DIR` but rename it with the name of a
    command you want to be able to run in the container.

    For our example:
    ```console
    cp ./command ~/exampleproj/bin/node
    ```

5.  Ensure the permissions on that new copy of this file allow execution:
    ```console
    chmod 775 ~/exampleproj/bin/node
    ```

6.  Edit that new copy of the command file. Look for the two sections that
    have `CHANGEME` in the comment and make changes according to the
    directions. The changes are:
    * Set the variable `IMAGE` to the name (and optionally tag or digest)
      of the Docker image you want to use.
    * Set the variable `CONTAINIT` to the path to the containit.sh script.

    For our example, we want to use the official Node.js 9.2.0 container from
    DockerHub and we put containit.sh in `BIN_DIR`, so we'll set them
    like this:
    ```console
    IMAGE=node:9.2.0
    CONTAINIT="${BIN_DIR}/containit.sh"
    ```

    We now have our first container command ready to run!
    ```console
    ~/exampleproj/bin/node --version
    v9.2.0
    ```

7.  For the rest of the commands, we want to use the same node:9.2.0
    Docker image, so all we need to do is to create symbolic links to our
    edited file above with the names of the commands we want to run in the
    container.

    We also want to run node, gulp, and bash, so we'll create 3 symbolic
    links in `BIN_DIR`:
    ```console
    cd ~/exampleproj/bin
    ln -s node npm
    ln -s node gulp
    ln -s node bash
    ```

8.  Run your commands using the soft links you just created. For example,
    to run npm:
    ```console
    cd ~/exampleproj
    bin/npm install express
    ```
    
    Here, the npm that runs is the version bundled into the node:9.2.0
    container we specified above.
