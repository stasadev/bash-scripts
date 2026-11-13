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
script_version="1.2.0"

# repos processed at once, git hosts drop SSH connections when there are too many
jobs="${GIT_MASS_JOBS:-8}"

function usage() {
    info "Usage: git-mass [arg]

Arguments:
    checkout (switch branches or restore working tree files)
    gc (cleanup unnecessary files and optimize the local repository, one repo at a time)
    gone (interactive delete for local branches that were deleted from a remote)
    maintenance (register repos for background maintenance: hourly prefetch, daily repack)
    pull (sync forks with upstream, fetch from all remotes, update the current branch, fast-forward other branches)
    sync (sync forks with upstream, fetch from all remotes, fast-forward branches that are not checked out)

    git ... (any other git command to run in sub-folders)

Environment:
    GIT_MASS_JOBS (repos processed at once, default: 8)"
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
    local serial="${serial:-}"

    local repos=() submodules=()
    mapfile -t repos < <(find . -mindepth 1 -maxdepth 2 -name '*.git' -printf "${PWD}/%P\n" | sed 's/\/\.git$//' | sort)

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

    if [[ "${serial}" == "yes" ]]; then
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
        # run several repos at once, parallel prints the output of each repo when it finishes
        printf "%s\n" "${repos[@]}" | PARALLEL_SHELL=bash parallel --will-cite --jobs "${jobs}" "${@}"
    fi

    success "'${PWD}' done ${repos_count} repo(s)."
}

function git-mass-checkout() {
    git -C "${1}" checkout .
}

# gc uses all CPU cores itself, so repos go one at a time
function git-mass-serial-gc() {
    info "Garbage collect '${PWD}'"
    git gc
}

# register writes ~/.gitconfig, so repos go one at a time
function git-mass-serial-maintenance() {
    info "Register maintenance '${PWD}'"
    git maintenance register
}

# start must run inside a repo, it registers it and sets up the scheduler (systemd timers on Linux)
function maintenance-start() {
    local repo
    repo="$(git config get --global --all maintenance.repo 2>/dev/null | tail -1 || true)"
    if [[ "${repo}" != "" ]]; then
        git -C "${repo}" maintenance start
        success "Background maintenance is scheduled, 'git maintenance unregister' in a repo opts it out."
    fi
}

# in a fork with an "upstream" remote, only upstream brings tags,
# otherwise fetch.pruneTags deletes upstream tags missing in origin, and fetching upstream brings them back,
# pruneTags fetches tags even with --no-tags, so it is disabled for origin too
function git-mass-fork-tags() {
    git -C "${1}" remote get-url upstream >/dev/null 2>&1 || return 0
    git -C "${1}" remote get-url origin >/dev/null 2>&1 || return 0
    # keep what was set by hand
    [[ "$(git -C "${1}" config get remote.origin.tagOpt 2>/dev/null)" == "" ]] || return 0

    git -C "${1}" config remote.origin.tagOpt --no-tags
    git -C "${1}" config remote.origin.pruneTags false
    info "Fork '${1}'"
    printf "\n%s\n\n" "origin brings no tags now, only upstream does"
}

# in a fork with an "upstream" remote, fast-forward the fork's default branch to the same upstream branch,
# like the "Sync fork" button, a branch with its own commits is left alone
function git-mass-fork-sync() {
    git -C "${1}" remote get-url upstream >/dev/null 2>&1 || return 0
    git -C "${1}" remote get-url origin >/dev/null 2>&1 || return 0

    # origin/HEAD comes from "git clone", a remote added by hand doesn't have it
    if ! git -C "${1}" symbolic-ref --quiet refs/remotes/origin/HEAD >/dev/null; then
        git -C "${1}" remote set-head origin --auto >/dev/null 2>&1 || return 0
    fi

    local branch result
    branch="$(git -C "${1}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" || return 0
    branch="${branch#origin/}"

    # origin too, the fork could have changed since the last fetch, e.g. after the "Sync fork" button
    if ! result="$(git -C "${1}" fetch --quiet --multiple origin upstream 2>&1)"; then
        warning "Unable to fetch '${1}'"
        printf "\n%s\n\n" "${result}"
        return 0
    fi

    git -C "${1}" rev-parse --verify --quiet "refs/remotes/upstream/${branch}" >/dev/null || return 0
    # nothing new upstream
    git -C "${1}" merge-base --is-ancestor "upstream/${branch}" "origin/${branch}" 2>/dev/null && return 0

    if ! git -C "${1}" merge-base --is-ancestor "origin/${branch}" "upstream/${branch}" 2>/dev/null; then
        warning "Unable to sync fork '${1}'"
        printf "\n%s\n\n" "origin/${branch} has commits that upstream/${branch} doesn't"
    # --no-verify: it only moves the branch to commits upstream already has, pre-push hooks have nothing to check
    elif ! result="$(git -C "${1}" push --quiet --no-verify origin "refs/remotes/upstream/${branch}:refs/heads/${branch}" 2>&1)"; then
        warning "Unable to sync fork '${1}'"
        printf "\n%s\n\n" "${result}"
    else
        info "Sync fork '${1}'"
        printf "\n%s\n\n" "origin/${branch} is now at upstream/${branch}"
    fi
}

# --no-rebase: a rebase refuses any uncommitted change, a fast-forward merge only the ones it would overwrite
# --no-autostash: rebase.autoStash would leave conflict markers in repos nobody looks at
function git-mass-pull() {
    git-mass-fork-tags "${1}"
    git-mass-fork-sync "${1}"

    local result
    if result="$(git -C "${1}" pull --ff-only --no-rebase --no-autostash --all 2>&1)"; then
        if [[ "$(echo "${result}" | grep -v -e "^Already up to date.$" -e "^Fetching")" != "" ]]; then
            info "Pull '${1}'"
            printf "\n%s\n\n" "${result}"
        fi
        if [[ -f "${1}/.gitmodules" ]]; then
            local submodule_update
            submodule_update="$(git -C "${1}" submodule update --init --recursive 2>&1)"
            if [[ "${submodule_update}" != "" ]]; then
                info "Submodules update '${1}'"
                printf "\n%s\n\n" "${submodule_update}"
            fi
        fi
    else
        warning "Unable to pull '${1}'"
        printf "\n%s\n\n" "${result}"
    fi

    # pull has fetched all remotes, the rest needs no network
    git-mass-fast-forward "${1}"
}

function git-mass-sync() {
    git-mass-fork-tags "${1}"
    git-mass-fork-sync "${1}"

    local result
    if result="$(git -C "${1}" fetch --all 2>&1)"; then
        if [[ "$(echo "${result}" | grep -v -e "^Fetching")" != "" ]]; then
            info "Fetch '${1}'"
            printf "\n%s\n\n" "${result}"
        fi
    else
        warning "Unable to fetch '${1}'"
        printf "\n%s\n\n" "${result}"
    fi

    git-mass-fast-forward "${1}"
}

# move local branches to their upstream when they are only behind it,
# branches checked out in any worktree are skipped, pull updates the current one,
# ":" separates fields because it can't be in a ref name
function git-mass-fast-forward() {
    local branch upstream track worktree updated=()
    while IFS=: read -r branch upstream track worktree; do
        if [[ "${track}" == behind* && "${worktree}" == "" ]] &&
            git -C "${1}" update-ref "refs/heads/${branch}" "${upstream}" 2>/dev/null; then
            updated+=("${branch}")
        fi
    done < <(git -C "${1}" for-each-ref --format='%(refname:short):%(upstream):%(upstream:track,nobracket):%(worktreepath)' refs/heads)

    if [[ ${#updated[@]} -gt 0 ]]; then
        info "Fast-forward '${1}'"
        printf "\n%s\n\n" "${updated[*]}"
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

for tool in git awk xargs parallel; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        failure "Install '${tool}' to run this script."
    fi
done

if [[ $(type -t "git-mass-interactive-${1-}") == function ]]; then
    serial=yes run "git-mass-interactive-${1}"
elif [[ $(type -t "git-mass-serial-${1-}") == function ]]; then
    serial=yes run "git-mass-serial-${1}"
    if [[ "${1}" == "maintenance" ]]; then
        maintenance-start
    fi
elif [[ $(type -t "git-mass-${1-}") == function ]]; then
    if [[ "${1}" == "checkout" ]] && ! confirm "Run checkout?" no; then
        exit 1
    fi

    export -f git-mass-"${1}" git-mass-fast-forward git-mass-fork-tags git-mass-fork-sync
    run "git-mass-${1}"
elif [[ "${#}" -gt 0 ]]; then
    run_custom_command=yes run "${@}"
else
    script_intro
    usage
fi
