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
script_name="Systemctl Toggle"
# shellcheck disable=SC2034
script_version="1.0.0"

script_intro

opt_user=false
opt_help=false
opt_interactive=false
services=()

n=1
while [[ $# -gt 0 ]]; do
    case "${1}" in
    -*) break ;;
    *)
        services+=("${1}")
        n=$((n + 1))
        ;;
    esac
    shift
done

while getopts iuh OPT; do
    case "${OPT}" in
    i) opt_interactive=true ;;
    u) opt_user=true ;;
    *) opt_help=true ;;
    esac
done

if [[ ${#services[@]} -eq 0 ]]; then
    opt_help=true
fi

if "${opt_help}"; then
    info "Usage: systemctl-toggle [service] [options]

Options:
    [no option] (start or stop as root)
    -h (help)
    -i (interactive)
    -u (start or stop as user)"
    exit 0
fi

function systemctl-run-root() {
    local sudo="sudo" && [[ "${opt_interactive}" == "true" ]] && sudo="pkexec"

    for service in "${services[@]}"; do
        local message="Started ${service} as root."
        local action="start"

        if [[ "$(systemctl is-active "${service}")" == "active" ]]; then
            message="Stopped ${service} as root."
            action="stop"
        fi

        "${sudo}" systemctl "${action}" "${service}"
        success "${message}" && [[ "${opt_interactive}" == "true" ]] && notify-send "${service}" "${message}"
    done
}

function systemctl-run-user() {
    for service in "${services[@]}"; do
        local message="Started ${service} as user."
        local action="start"

        if [[ "$(systemctl --user is-active "${service}")" == "active" ]]; then
            message="Stopped ${service} as user."
            action="stop"
        fi

        [[ "${opt_interactive}" == "true" ]] && notify-send "${service}" "${message}"
        systemctl --user "${action}" "${service}" && success "${message}"
    done
}

function systemctl-toggle-warp() {
    services=("warp-svc")

    for service in "${services[@]}"; do
        if [[ "$(systemctl is-active "${service}")" == "active" ]]; then
            warp-cli disconnect && systemctl-run-root
        else
            systemctl-run-root && sleep 1 && warp-cli connect && sleep 1
        fi

        if "${opt_interactive}"; then
            notify-send "${service}" "$(jq '.ip, .city, .country, .org' <<< "$(curl ipinfo.io)")"
        fi
    done
}

# for extended scenarios
#function systemctl-toggle-samba() {
#    services=("smb" "nmb")
#    systemctl-run-root
#}

if [[ $(type -t systemctl-toggle-"${services[*]}") == function ]]; then
    systemctl-toggle-"${services[*]}"
    exit 0
fi

if "${opt_user}"; then
    systemctl-run-user
else
    systemctl-run-root
fi
