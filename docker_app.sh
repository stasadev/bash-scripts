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
readonly script_name="Docker App"
# shellcheck disable=SC2034
readonly script_version="1.3.0"

#}}}

main() {
    run_init
    # these functions stop subsequent script execution
    run_setup_desktop_shortcut
    run_pull_image
    run_container_logs
    run_container_sh
    run_metube_cookies

    # these functions are executed sequentially
    run_start_or_stop

    info "Done."
}

#{{{ Functions

run_help() {
    info "Usage: docker-app [arguments]

primary args:
buggregator # Ultimate Debugging Server for PHP
lama-cleaner # image inpainting tool powered by SOTA AI Model
metube # youtube-dl web UI
searxng # a privacy-respecting, hackable metasearch engine
rembg # tool to remove images background
asf # Steam cards farming

use env DOCKER_APP_MOUNT_DIR to mount another folder (default is ${HOME}/Downloads)
use env DOCKER_APP_PORT to bind non-default port for the service
use env DOCKER_APP_TAG to pull a specific image tag
use env DOCKER_NETWORK to connect the container to a specific network
use env BROWSER to open the specific browser
use env WAIT_UI_SEC to wait before opening the browser (default is 1 sec)

metube env: METUBE_YTDL_OPTIONS, METUBE_OUTPUT_TEMPLATE
asf env: ASF_CRYPTKEY, ASF_ARGS

secondary args:
i, interactive (to run from desktop shortcut)
log, logs      (view container logs)
p, pull        (pull the newest image)
s, setup       (create a desktop shortcut)
sh, bash       (enter the container)
  root         (under root user)
cookies        (show cookies instructions for metube)"
    exit 0
}

has_arg() {
    local param="${1}"
    local params="${args[*]}"

    # shortcuts for arguments
    [[ " ${params} " =~ " i " ]] && params=" ${params} interactive "
    [[ " ${params} " =~ " p " ]] && params=" ${params} pull "
    [[ " ${params} " =~ " s " ]] && params=" ${params} setup "

    # shellcheck disable=SC2076
    if [[ " ${params} " =~ " ${param} " ]]; then
        return 0
    else
        return 1
    fi
}

run_init() {
    readonly network="${DOCKER_NETWORK:-bridge}"
    wait_ui_sec="${WAIT_UI_SEC:-1}"
    # check for numeric value
    [[ ! "${wait_ui_sec}" =~ ^[0-9]+$ ]] && wait_ui_sec=1

    if has_arg "buggregator"; then

        readonly app_name="Buggregator"
        readonly app_comment="Ultimate Debugging Server for PHP"
        readonly image_name="ghcr.io/buggregator/server:${DOCKER_APP_TAG:-latest}"
        readonly container_name="buggregator"
        readonly port="${DOCKER_APP_PORT:-8000}"

    elif has_arg "lama-cleaner"; then

        readonly app_name="Lama Cleaner"
        readonly app_comment="Lama Cleaner (Image inpainting tool)"
        readonly image_name="cwq1913/lama-cleaner:${DOCKER_APP_TAG:-cpu-1.2.5}"
        readonly container_name="lama-cleaner"
        readonly mount_dir="${DOCKER_APP_MOUNT_DIR:-${HOME}/Downloads/${container_name}}"
        readonly port="${DOCKER_APP_PORT:-8080}"
        [[ ${wait_ui_sec} == 1 ]] && wait_ui_sec=15

    elif has_arg "metube"; then

        readonly app_name="MeTube"
        readonly app_comment="YouTube Downloader"
        readonly image_name="alexta69/metube:${DOCKER_APP_TAG:-latest}"
        readonly container_name="metube"
        readonly mount_dir="${DOCKER_APP_MOUNT_DIR:-${HOME}/Downloads/${container_name}}"
        readonly port="${DOCKER_APP_PORT:-8081}"

    elif has_arg "searxng"; then

        readonly app_name="SearXNG"
        readonly app_comment="A privacy-respecting, hackable metasearch engine"
        readonly image_name="searxng/searxng:${DOCKER_APP_TAG:-latest}"
        readonly container_name="searxng"
        readonly mount_dir="${DOCKER_APP_MOUNT_DIR:-${HOME}/Downloads/${container_name}}"
        readonly port="${DOCKER_APP_PORT:-8082}"

    elif has_arg "rembg"; then

        readonly app_name="Rembg"
        readonly app_comment="Tool to remove images background"
        readonly image_name="danielgatis/rembg:${DOCKER_APP_TAG:-latest}"
        readonly container_name="rembg"
        readonly mount_dir="${DOCKER_APP_MOUNT_DIR:-${HOME}/Downloads/${container_name}}"
        readonly port="${DOCKER_APP_PORT:-5000}"
        [[ ${wait_ui_sec} == 1 ]] && wait_ui_sec=40

    elif has_arg "asf"; then

        readonly app_name="ASF"
        readonly app_comment="Steam cards farming"
        readonly image_name="justarchi/archisteamfarm:${DOCKER_APP_TAG:-released}"
        readonly container_name="asf"
        readonly mount_dir="${DOCKER_APP_MOUNT_DIR:-${HOME}/Downloads/${container_name}}"
        readonly port="${DOCKER_APP_PORT:-1242}"

    else
        script_intro
        run_help
    fi

    readonly desktop_entry="[Desktop Entry]
Categories=Utility;
Comment=${app_comment}
Exec=bash -ci 'docker-app interactive ${container_name}'
Icon=utilities-terminal
Name=${app_name}
Terminal=false
Type=Application"
    readonly desktop_shortcut="${HOME}/.local/share/applications/${container_name}.desktop"
}

run_metube_cookies() {
    has_arg "metube" || return 0
    has_arg "cookies" || return 0

    info "How to send browser cookies:
1. Install in your browser an extension to extract cookies
   Firefox https://addons.mozilla.org/en-US/firefox/addon/export-cookies-txt/
   Chrome https://chrome.google.com/webstore/detail/get-cookiestxt/bgaddhkoddajcdgocldbbfleckgcbcid
2. Extract the cookies you need with the extension and rename the file cookies.txt
3. Drop the file here ${mount_dir}/cookies.txt
4. Restart the container"
    exit 0
}

run_setup_desktop_shortcut() {
    has_arg "setup" || return 0

    if [[ -f "${desktop_shortcut}" ]]; then
        info "Removing old shortcut ${desktop_shortcut}"
        rm -f "${desktop_shortcut}"
    fi

    echo "${desktop_entry}" > "${desktop_shortcut}" && \
        success "Added a new desktop shortcut ${desktop_shortcut}"
    exit 0
}

run_pull_image() {
    has_arg "pull" || return 0

    docker pull "${image_name}"
    success "Pulled image ${image_name}"
    exit 0
}

run_container_logs() {
    has_arg "log" || has_arg "logs" || return 0

    docker logs -f "${container_name}"
    exit 0
}

run_container_sh() {
    has_arg "sh" || has_arg "bash" || return 0

    if has_arg "bash"; then
        local shell="bash"
    else
        local shell="sh"
    fi

    if has_arg "root"; then
        docker exec -u root -it "${container_name}" "${shell}"
    else
        docker exec -it "${container_name}" "${shell}"
    fi

    exit 0
}

run_start_or_stop() {
    if [[ ! "$(docker ps -q -f name="${container_name}")" ]]; then
        if [[ "$(docker ps -aq -f status=exited -f name="${container_name}")" ]]; then
            docker rm "${container_name}"
        fi

        if has_arg "interactive"; then
            notify-send "${container_name}" "Started"
        fi

        success "Starting..."

        local docker_opts=()

        if has_arg "buggregator"; then
            docker_opts=(
                -p "127.0.0.1:${port}:8000"
                "${image_name}"
            )
        elif has_arg "lama-cleaner"; then
            mkdir -p "${mount_dir}/"{torch_cache,huggingface_cache}
            docker_opts=(
                -p "127.0.0.1:${port}":8080
                -v "${mount_dir}/torch_cache":/root/.cache/torch
                -v "${mount_dir}/huggingface_cache":/root/.cache/huggingface
                "${image_name}"
                lama-cleaner --device=cpu --port=8080 --host=0.0.0.0
            )
        elif has_arg "metube"; then
            mkdir -p "${mount_dir}/cache"
            docker_opts=(
                -p "127.0.0.1:${port}":8081
                -v "${mount_dir}":/downloads
                --user "$(id -u)":"$(id -g)"
                "${image_name}"
            )
            if [[ "${METUBE_YTDL_OPTIONS:-}" != "" ]]; then
                docker_opts=(-e YTDL_OPTIONS="${METUBE_YTDL_OPTIONS}" "${docker_opts[@]}")
            else
                docker_opts=(-e YTDL_OPTIONS='{"cachedir":"/downloads/cache","cookiefile":"/downloads/cookies.txt","subtitleslangs":["en.*","-live_chat"],"writesubtitles":true,"postprocessors":[{"key":"FFmpegEmbedSubtitle","already_have_subtitle":false},{"key":"SponsorBlock","categories":["sponsor","selfpromo","interaction","intro","outro","music_offtopic"],"when":"pre_process"},{"key":"ModifyChapters","remove_sponsor_segments":["sponsor","selfpromo","interaction","intro","outro","music_offtopic"]}],"verbose":true}' "${docker_opts[@]}")
            fi
            if [[ "${METUBE_OUTPUT_TEMPLATE:-}" != "" ]]; then
                docker_opts=(-e OUTPUT_TEMPLATE="${METUBE_OUTPUT_TEMPLATE}" "${docker_opts[@]}")
            else
                docker_opts=(-e OUTPUT_TEMPLATE='%(upload_date>%Y-%m-%d)s [%(uploader|Unknown)s] %(title)s [%(resolution)s].%(ext)s' "${docker_opts[@]}")
            fi
        elif has_arg "searxng"; then
            mkdir -p "${mount_dir}"
            docker_opts=(
                -p "127.0.0.1:${port}":8080
                -v "${mount_dir}:/etc/searxng"
                -e "BASE_URL=http://localhost:${port}/"
                "${image_name}"
            )
        elif has_arg "rembg"; then
             docker_opts=(
                -p "127.0.0.1:${port}":5000
                "${image_name}"
                s
            )
        elif has_arg "asf"; then
            mkdir -p "${mount_dir}/"{config,logs,plugins}
            if [[ ! -f "${mount_dir}/config/IPC.config" ]]; then
                echo '{"Kestrel":{"Endpoints":{"HTTP":{"Url":"http://*:1242"}},"KnownNetworks":["10.0.0.0/8","172.16.0.0/12","192.168.0.0/16"]}}' | jq --indent 4 > "${mount_dir}/config/IPC.config"
            fi
            if [[ ! -f "${mount_dir}/config/ASF.json" ]]; then
                echo '{"Headless": true}' | jq --indent 4 > "${mount_dir}/config/ASF.json"
            fi
            docker_opts=(
                -p "127.0.0.1:${port}":1242
                -v "${mount_dir}/config":/app/config
                -v "${mount_dir}/logs":/app/logs
                -v "${mount_dir}/plugins":/app/plugins
                -e ASF_USER="$(id -u)"
                --user "$(id -u)":"$(id -g)"
                "${image_name}"
            )
            if [[ "${ASF_CRYPTKEY:-}" != "" ]]; then
                docker_opts=(-e ASF_CRYPTKEY="${ASF_CRYPTKEY}" "${docker_opts[@]}")
            fi
            if [[ "${ASF_ARGS:-}" != "" ]]; then
                docker_opts=(-e ASF_ARGS="${ASF_ARGS}" "${docker_opts[@]}")
            fi
        fi

        if docker network inspect "${network}" >/dev/null 2>&1; then
            docker_opts=(--network "${network}" "${docker_opts[@]}")
        fi

        if has_arg "interactive" && [[ "$(docker images -q --filter=reference="${image_name}")" == "" ]]; then
            notify-send "${container_name}" "Pulling image ${image_name}"
        fi

        docker run -d --rm --name "${container_name}" "${docker_opts[@]}"

        local open_url="http://localhost:${port}"

        local wait_message="Waiting ${wait_ui_sec} seconds before opening the browser..."

        if has_arg "interactive"; then
            [[ "${wait_ui_sec}" -gt 1 ]] && notify-send "${container_name}" "${wait_message}"
            sleep "${wait_ui_sec}"

            if [[ -n "${BROWSER:-}" ]]; then
                ${BROWSER} "${open_url}"
            else
                xdg-open "${open_url}"
            fi
        fi

        [[ "${wait_ui_sec}" -gt 1 ]] && info "${wait_message}"
        info "${open_url}"
        success "${container_name} started."
    else
        if has_arg "interactive"; then
            notify-send "${container_name}" "Stopped"
        fi

        success "Stopping..."
        docker stop "${container_name}"

        if has_arg "metube"; then
            rm -f "${mount_dir}/cookies.txt"
            rm -rf "${mount_dir}/cache"
        fi

        success "${container_name} stopped."
    fi
}

#}}}

main "${@}"
