#!/usr/bin/env bash
#
# Author: Stanislav Zhuk <stanislav.zhuk.work@gmail.com>
#

function primary() {
    echo -e "\033[0;34m${1}\033[0m"
}

function secondary() {
    echo -e "\033[0;35m${1}\033[0m"
}

function success() {
    echo -e "\033[0;32m${1}\033[0m"
}

function warning() {
    echo -e "\033[0;33m${1}\033[0m"
}

function info() {
    echo -e "\033[0;36m${1}\033[0m"
}

function danger() {
    echo -e "\033[0;31m${1}\033[0m"
}

function failure() {
    echo >&2 -e "\033[0;31m${1}\033[0m"
    if [[ $(type -t usage) == function ]]; then
        echo
        usage
    fi
    exit 1
}

# shellcheck disable=SC2120
function confirm() {
    local message="${1:-Are you sure?}"

    echo
    read -rp "${message} (Y/n): " REPLY
    echo

    # convert to lowercase
    REPLY="${REPLY,,}"

    if [[ -z "${REPLY}" || "${REPLY}" == "y" || "${REPLY}" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

function script_intro() {
    echo -e "${script_name:-Name} \033[0;32m${script_version:-Version}\033[0m\n"
}

export -f \
    primary \
    secondary \
    success \
    warning \
    info \
    danger \
    failure \
    confirm \
    script_intro
