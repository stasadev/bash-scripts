# Bash Scripts

A collection of bash scripts that I can share publicly.

![platform](https://img.shields.io/badge/platform-Linux-blue.svg)
![license](https://img.shields.io/github/license/stasadev/bash-scripts)

## Quick Start

Clone this git repo to a fixed location on your computer and add [bash-scripts/bin](bin) it to your `$PATH`.

```bash
cd ~
git clone https://github.com/stasadev/bash-scripts.git bash-scripts
cd bash-scripts/bin
export PATH="$(pwd):$PATH"
```

## Docker App [docker-app](docker_app.sh)

When using a dockerized application, you usually run it from a terminal and do all the boring work like port forwarding, mounting directories, starting/stopping/pulling containers, etc.

It is better to prepare everything in a script, and create a desktop shortcut to quickly start/stop the application.

I added a quick way to launch (thanks to all the developers of these apps):
* [lama-cleaner](https://github.com/Sanster/lama-cleaner): image inpainting tool powered by SOTA AI Model
* [metube](https://github.com/alexta69/metube): youtube-dl web UI
* [rembg](https://github.com/danielgatis/rembg): tool to remove images background
* [revanced-builder](https://github.com/reisxd/revanced-builder): a NodeJS ReVanced builder

For help, run `docker-app`.

To install an app from the list above, run the first time setup `docker-app setup [app-name]`. It will create a desktop shortcut at `~/.local/share/applications/[app-name].desktop`. When you run this shortcut it starts the container, a second run of this shortcut stops the container.

You can change the mount directory, application port and image tag using env variables, edit the desktop shortcut like this:

```text
Exec=bash -ci 'DOCKER_APP_MOUNT_DIR=/custom-path DOCKER_APP_PORT=12345 DOCKER_APP_TAG=latest docker-app interactive [app-name]'
```

## License

MIT License.
