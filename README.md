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

## Git Mass [git-mass](git_mass.sh)

When you have several git repos in one parent directory, it becomes hard to keep everything up to date. You need to go in every directory and pull one by one.

I created a script that can run git commands on multiple repositories in parallel, including submodules.

[hub](https://github.com/github/hub) can be used under the hood.

For help, run `git-mass`.

I like to run `git-mass pull` every day when I start work to stay in sync with all repos.

```text
$ pwd
/home/user/repos

$ ls
git-repo-1 git-repo-2

$ git-mass pull
Pull '/home/user/repos/git-repo-1'

remote: Enumerating objects: 11, done.
remote: Counting objects: 100% (11/11), done.
remote: Compressing objects: 100% (11/11), done.
remote: Total 11 (delta 1), reused 0 (delta 0), pack-reused 0
From github.com:private-repo/git-repo-1
 * [new branch] feature/new-report -> origin/feature/new-report
Already up to date.

'/home/user/repos' done 2 repo(s).
```

To execute any git command in serial mode, such as `git status`:

```text
$ git-mass git status
Running 'git status' in '/home/user/repos/git-repo-1'...
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean

Running 'git status' in '/home/user/repos/git-repo-1'...
On branch main
Your branch is up to date with 'origin/main'.
```

## PHP After [php-after](php_after.sh)

When you clone an existing repo or create a new repo for a PHP project, you need to do some work, for example:

* install composer packages,
* set correct the file permissions (if someone mixed them up),
* reset git repo to its original state (remove all gitignore files),
* integrate code style rules,
* and so on.

This script will help you to do everything in one go.

For help, run `php-after`.

The main focus is made on Laravel projects.

```bash
# add slack integration
php-after laravel slack
# add ide-helper integration
php-after laravel ide
# upgrade the repo to latest laravel version
php-after laravel upgrade
# and many other commands...
```

## License

MIT License.
