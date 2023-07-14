#!/usr/bin/env bash
#
# Author: Stanislav Zhuk <stanislav.zhuk.work@gmail.com>
#

#{{{ bash settings

set -o errexit
set -o nounset
set -o pipefail

#}}}

# shellcheck disable=SC1090
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/output_helpers.sh"

# shellcheck disable=SC2034
script_name="PHP Create"
# shellcheck disable=SC2034
script_version="1.0.2"

script_intro

function usage() {
    info "Usage: php-create [package] (version - optional) [folder]

Arguments:
    [package]: valid composer package or predefined:
        cakephp
        codeigniter4
        drupal
        laravel
        symfony
        yii2
    (version): '10.*', '^10.0', 'v10.1.0', etc.
        if version is not provided, the latest version will be used."
}

info "Changing directory to ${PWD}"
echo

cd "${PWD}" || failure "Unable to change the directory."

if [[ "${PWD}" = "${HOME}" ]]; then
    failure "Do not run from the HOME dir."
fi

if [[ -d ".git" ]]; then
    failure "Do not run inside another git repo."
fi

arguments=("${@}")

if [[ ${#arguments[@]} -le 1 ]] || [[ ${#arguments[@]} -ge 4 ]]; then
    failure "Wrong number of arguments."
fi

package=""
version=""
folder=""

if [[ ${#arguments[@]} -eq 2 ]]; then
    package="${1}"
    version=""
    folder="${2}"

    if [[ "${folder}" =~ ^[0-9] ]]; then
        failure "Folder name cannot start with a number."
    fi
elif [[ ${#arguments[@]} -eq 3 ]]; then
    package="${1}"
    version="${2}"
    folder="${3}"
fi

if [[ -d "${folder}" ]]; then
    failure "Folder '${folder}' already exists."
fi

# composer help create-project
flags=(
    --ignore-platform-reqs
    --no-install
    --no-plugins
    --no-scripts
    --profile
)

note=""

if [[ "${package}" == "cakephp" ]]; then
    package="cakephp/app"
fi

if [[ "${package}" == "codeigniter4" ]]; then
    package="codeigniter4/appstarter"
fi

if [[ "${package}" == "drupal" ]]; then
    package="drupal/recommended-project"
    note="Run: cd ${folder} && php -d memory_limit=256M web/core/scripts/drupal quick-start demo_umami"
fi

if [[ "${package}" == "laravel" ]]; then
    package="laravel/laravel"
fi

if [[ "${package}" == "symfony" ]]; then
    package="symfony/skeleton"
    note="If this is not a library, run: cd $folder && composer require webapp --ignore-platform-reqs"
fi

if [[ "${package}" = "yii2" ]]; then
    package="yiisoft/yii2-app-basic"
fi

composer create-project "${flags[@]}" "${package}" "${folder}" "${version}"

cd "${folder}" || failure "Unable to change the directory."

echo
info "Current git user - $(git config user.name) <$(git config user.email)>"

if confirm "Create a git repository?"; then
    echo
    printf "Commit message (Init): "
    read -r commit

    if [[ "${commit}" == "" ]]; then
        commit="Init"
    fi

    echo
    git init
    git add .
    git commit -m "${commit}"
    echo
    success "Created a git repository."
else
    warning "Skipped creating a git repository."
fi

if [[ "${note}" != "" ]]; then
    echo
    secondary "${note}"
fi

echo
info "Done."
