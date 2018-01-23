
## Makefile targets

- `docker` (default target)
    - Builds the docker image unconditionally
- `docker-stamp`
    - Only builds the docker image if we think it might have changed,
      due to changes in this directory.
- `clean`
    - Removes generated files from this directory.
      (Does not affect the docker image itself)
- `run`
    - Conditionally rebuilds the docker image (that is, depends on `docker-stamp`),
      then runs `./android.sh` to launch the docker image with default options.

## Launch script

**`./android.sh`**

Will start up the Docker image - by default mapping the following directories:

- `/opt/android/tegra-android` to `/opt/tegra-android` inside the image
- `/opt/android/ccache` to `/opt/ccache` inside the image
- `/opt/android/tnspec-workspace` to `/opt/tnspec-workspace` inside the image (used for storing per-device spec/config files by flashing scripts including `tnspec.py`)

Look at the top of the script to see easy overrides (like changing the source tree, etc).

If you don't pass any arguments, a bash shell will be started for you interactively
(as the unprivileged `android` user created inside the docker image).

Otherwise, the arguments to this shell script will be run as the unprivileged `android` user in the image.

Feel free to make symlinks to this file in, e.g., your `/opt/android` directory.

## Configuration
Can place a file named `gid` in either this directory or in a directory where you symlink the `android.sh` file to and run from,
if you'd like to set the group ID (numeric) explicitly to something other than the current user's "main" group.
