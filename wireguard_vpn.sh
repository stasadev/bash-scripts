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
script_name="Wireguard VPN"
# shellcheck disable=SC2034
script_version="1.0.0"

script_intro

opt_help=false
opt_down=false
opt_up=false

while getopts dhu OPT; do
    case "${OPT}" in
        d) opt_down=true ;;
        h) opt_help=true ;;
        u) opt_up=true ;;
        *) opt_help=true ;;
    esac
done

if [[ ${opt_up} == false ]] && [[ ${opt_down} == false ]]; then
    opt_help=true
fi

if "${opt_help}"; then
    info "Usage: wireguard-vpn [options]

Options:
    -u INTERFACE_NAME (up)
    -d INTERFACE_NAME (down)
    -h (help)"
    exit 0
fi

function current_port() {
    sudo wg show | grep -oP "listening port: \K.*"
}

function invalid_interface() {
    failure "Please provide a valid interface name"
}

function vpnup() {
    if [[ -z "${1}" ]]; then
        invalid_interface
    fi

    if nmcli con show --active | grep -qw "^${1}"; then
        success "Already activated"
        exit 0
    fi

    if nmcli con show | grep -qw "^${1}"; then
        nmcli con up id "${1}"
        #sudo ufw allow "$(current_port)"/udp
    else
        invalid_interface
    fi
}

function vpndown() {
    if [[ -z "${1}" ]]; then
        invalid_interface
    fi

    if nmcli con show --active | grep -qw "^${1}"; then
        #sudo ufw delete allow "$(current_port)"/udp
        nmcli con down id "${1}"
        exit 0
    fi

    if nmcli con show | grep -qw "^${1}"; then
        success "Already deactivated"
        exit 0
    else
        invalid_interface
    fi
}

if "${opt_up}"; then
    vpnup "${2}"
elif "${opt_down}"; then
    vpndown "${2}"
fi
