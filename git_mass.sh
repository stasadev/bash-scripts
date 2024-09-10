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
script_name="Git Mass"
# shellcheck disable=SC2034
script_version="1.1.2"

function usage() {
    info "Usage: git-mass [arg]

Arguments:
    checkout (switch branches or restore working tree files)
    gc (cleanup unnecessary files and optimize the local repository)
    gone (interactive delete for local branches that were deleted from a remote)
    pull (fetch from and integrate with another repository or a local branch)
    sync (hub-sync: fetch git objects from upstream and update local branches)

    git ... (any other git command to run in sub-folders)"
}

function checkout() { (
    [[ "${PWD}" != "${1}" ]] && cd "${1}"

    # switch from detached HEAD to the branch
    if ! git symbolic-ref -q HEAD >/dev/null 2>&1; then
        latest_branch="$(git for-each-ref --sort=-committerdate --format='%(refname:short)' --count=1 refs/heads/ 2>/dev/null || true)"
        if [[ "${latest_branch}" != "" ]]; then
            info "\nCheckout '${1}'...\n"
            git checkout "${latest_branch}"
        fi
    fi
); }

function run() {
    local run_custom_command="${run_custom_command:-}"
    local interactive="${interactive:-}"

    local repos=() submodules=()
    mapfile -t repos < <(find . -mindepth 1 -maxdepth 2 -name '*.git' -printf "${PWD}/%P\n" | sed 's/\/.git//' | sort)

    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]]; then
        mapfile -t submodules < <(git submodule status 2>/dev/null | awk '{print $2}' | xargs --no-run-if-empty realpath)
    fi

    # Filter out submodules from repos
    local filtered_repos=() repo
    for repo in "${repos[@]}"; do
        local is_submodule=false submodule
        for submodule in "${submodules[@]}"; do
            if [[ "${repo}" == "${submodule}" ]]; then
                is_submodule=true
                break
            fi
        done
        if ! ${is_submodule}; then
            filtered_repos+=("${repo}")
        fi
    done

    # Replace repos with the filtered list
    repos=("${filtered_repos[@]}")

    local repos_count
    repos_count=${#repos[@]}

    if [[ "${repos_count}" == 0 ]]; then
        warning "Git repo(s) in '${PWD}' not found."
    fi

    for repo in "${repos[@]}"; do
        checkout "${repo}"
    done

    if [[ "${interactive}" == "yes" ]]; then
        # run each repo sequentially
        for repo in "${repos[@]}"; do
            (cd "${repo}" && "${@}")
        done
    elif [[ "${run_custom_command}" == "yes" ]]; then
        # run each repo sequentially
        for repo in "${repos[@]}"; do
            info "\nRunning '${*}' in '${repo}'..."

            if ! (cd "${repo}" && "${@}"); then
                warning "Unable to '${*}' for '${repo}'."
            fi
        done
    else
        # run all repos at once
        printf "%s\n" "${repos[@]}" | xargs -P"${repos_count}" -I{} "${@}"
    fi

    success "'${PWD}' done ${repos_count} repo(s)."
}

function git-mass-checkout() {
    git -C "${1}" checkout .
}

function git-mass-gc() {
    git -C "${1}" gc --aggressive
}

function git-mass-pull() {
    local result
    if result="$(git -C "${1}" pull --ff-only --progress --all 2>&1)"; then
        if [[ "$(echo "${result}" | grep -v -e "^Already up to date.$" -e "^Fetching")" != "" ]]; then
            info "Pull '${1}'"
            printf "\n%s\n\n" "${result}"

            # sync all branches in the repo
            if command -v hub >/dev/null 2>&1; then
                (git-mass-sync "${1}")
            fi
        fi
        local submodule_update
        submodule_update="$(git -C "${1}" submodule update --init --recursive 2>&1)"
        if [[ "${submodule_update}" != "" ]]; then
            info "Submodules update '${1}'"
            printf "\n%s\n\n" "${submodule_update}"
        fi
    else
        warning "Unable to pull '${1}'"
        printf "\n%s\n\n" "${result}"

        # try to sync instead
        if command -v hub >/dev/null 2>&1; then
            (git-mass-sync "${1}")
        fi
    fi
}

function git-mass-sync() {
    local result
    if result="$(hub -C "${1}" sync --color 2>&1)"; then
        if [[ "${result}" != "" ]]; then
            info "Sync '${1}'"
            printf "\n%s\n\n" "${result}"
        fi
    else
        warning "Unable to sync '${1}'"
        printf "\n%s\n\n" "${result}"
    fi
}

# remove gone branches https://stackoverflow.com/a/33548037
function git-mass-interactive-gone() {
    local gone_branches=() gone_branch
    mapfile -t gone_branches < <(git for-each-ref --format '%(refname) %(upstream:track)' refs/heads | awk '$2 == "[gone]" {sub("refs/heads/", "", $1); print $1}' 2>/dev/null)
    for gone_branch in "${gone_branches[@]}"; do
        info "Found gone branch '${gone_branch}' in '$(pwd)' with commit:"
        echo
        git log -1 "${gone_branch}" | cat
        if confirm "Delete gone branch '${gone_branch}' in '$(pwd)'?" no; then
            if result=$(git branch -D "${gone_branch}" 2>&1); then
                if [[ "${result:-}" != "" ]]; then
                    info "Delete gone branches in '$(pwd)'"
                    printf "\n%s\n\n" "${result}"
                fi
            else
                warning "Unable to delete gone branches in '$(pwd)'"
                printf "\n%s\n\n" "${result}"
            fi
        else
            info "Skipped deleting gone branch '${gone_branch}'"
            echo
        fi
    done
}

for tool in git awk xargs; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        failure "Install '${tool}' to run this script."
    fi
done

if [[ $(type -t "git-mass-interactive-${1-}") == function ]]; then
    export -f git-mass-interactive-"${1}"
    interactive=yes run "git-mass-interactive-${1}"
elif [[ $(type -t "git-mass-${1-}") == function ]]; then
    if [[ "${1}" == "pull" ]]; then
        if command -v hub >/dev/null 2>&1; then
            export -f git-mass-sync
        else
            warning "Install 'hub' to use hub-sync."
        fi
    fi

    if [[ "${1}" == "sync" ]] && ! command -v hub >/dev/null 2>&1; then
        failure "Install 'hub' to use hub-sync."
    fi

    if [[ "${1}" == "checkout" ]] && ! confirm "Run checkout?" no; then
        exit 1
    fi

    export -f git-mass-"${1}"
    run bash -c ''"git-mass-${1}"' "${@}"' _ {}
elif [[ "${#}" -gt 0 ]]; then
    run_custom_command=yes run "${@}"
else
    script_intro
    usage
fi
