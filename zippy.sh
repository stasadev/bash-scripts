#!/usr/bin/env bash
#
# Author: Stanislav Zhuk <stanislav.zhuk.work@gmail.com>
#

#{{{ bash settings

set -o errexit
set -o nounset
set -o pipefail

#}}}

#{{{ init logic

# shellcheck disable=SC1090
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/output_helpers.sh"
# input arguments
readonly args=("${@}")
# shellcheck disable=SC2034
readonly script_name="Backup ZIP"
# shellcheck disable=SC2034
readonly script_version="1.0.0"

read -a include_list <<< "${include-"."}"
read -a exclude_list <<< "${exclude-}"
read -a internal_exclude_list <<< "${internal_exclude-"*/.ddev/* */.idea/* */.nuxt/* */.Trash-1000/* */lost+found/* */node_modules/* */vendor/*"}"
in_folder="${1:-"${PWD}"}"
zip_filename="${zip_filename-}"

#}}}

main() {
    if [[ ${zip_filename} == '' ]]; then
        script_intro
        run_help
    fi

    info "Changing directory to ${in_folder}"

    cd "${in_folder}" || failure "Unable to change the directory."

    [[ "${PWD}" == "${HOME}" ]] && failure "Do not run from the \$HOME dir."

    run_dependency_check
    run_zip

    info "Done."
}

#{{{ Functions

run_help() {
    info "Usage: zip_filename='' exclude='' internal_exclude='' include='' zippy [in_folder]

zip_filename - required, full or relative name without .zip
exclude, internal_exclude, include - optional, string arrays
in_folder - optional, current dir by default"
    exit 0
}

has_arg() {
    local param="${1}"
    local params="${args[*]}"

    # shellcheck disable=SC2076
    if [[ " ${params} " =~ " ${param} " ]]; then
        return 0
    else
        return 1
    fi
}

run_dependency_check() {
    if ! command -v zip >/dev/null 2>&1; then
        failure "Install the zip package first."
    fi
}

run_zip() {
    local include_args
    for path in "${include_list[@]}"; do
        include_args+=("${path}")
    done

    local exclude_args
    for path in "${exclude_list[@]}"; do
        exclude_args+=('-x' "${path}")
    done

    local internal_exclude_args
    for path in "${internal_exclude_list[@]}"; do
        internal_exclude_args+=('-x' "${path}")
    done

    local time
    time="$(date +'%Y-%m-%d-%H-%M-%S')"
    local zip_file="${zip_filename}-${time}.zip"

    zip -9 -r "${zip_file}" "${include_args[@]}" "${exclude_args[@]}" "${internal_exclude_args[@]}"

    if [[ ${zip_file} == /* ]]; then
        success "Saved to ${zip_file}"
    else
        success "Saved to ./${in_folder}/${zip_file}"
    fi
}

#}}}

main "${@}"
