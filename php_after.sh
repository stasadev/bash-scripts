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
# shellcheck disable=SC1090
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/php_after_data.sh"
# input arguments
readonly args=("${@}")
# shellcheck disable=SC2034
readonly script_name="PHP After"
# shellcheck disable=SC2034
readonly script_version="1.0.0"

#}}}

main() {
    if [[ ${#args[@]} -eq 0 ]] || has_arg "help" || has_arg "h"; then
        script_intro
        run_help
    fi

    info "Changing directory to ${PWD}"

    cd "${PWD}" || failure "Unable to change the directory."

    [[ "${PWD}" == "${HOME}" ]] && failure "Do not run from the \$HOME dir."

    # these functions stop subsequent script execution
    run_chmod
    run_git_reset
    run_laravel_pint
    run_laravel_upgrade

    # these functions are executed sequentially
    run_composer_install
    run_composer_list
    run_npm
    run_laravel_general
    run_laravel_php_cs_fixer
    run_laravel_ide_helper
    run_laravel_path
    run_laravel_slack
    run_laravel_sqlite
    run_laravel_stub

    info "Done."
}

#{{{ Functions

run_help() {
    info "Usage: php-after [arguments]

chmod       (sets correct file and folder permissions)
c, composer (installs packages from composer.json)
  list      (shows recommendations for composer packages)
h, help     (shows this help)
npm         (runs 'npm install', adds '.gitignore' for assets)
force       (used with other commands, overwrites changes)
revert      (used with other commands, reverts changes)
g, git
  clean     (resets project structure like after git clone)
  reset     (alias for 'clean')
l, laravel  (checks .env, removes Laravel caches)
  fixer     (installs php-cs-fixer in 'tools/php-cs-fixer')
  ide       (generates ide-helper files using a database from '.env')
  ide2      (generates ide-helper files using a temporary sqlite database)
  path      (adds path() helper)
  slack     (adds Slack integration for the project)
  sqlite    (configures the project database to 'database/database.sqlite')
  stub      (adds stubs for the project)
  upgrade   (downloads the latest laravel/laravel and replaces the files)
pint        (installs Laravel Pint PHP code style fixer)
  laravel   (writes laravel preset to the config file, used by default)
  psr12     (writes psr12 preset to the config file)
  symfony   (writes symfony preset to the config file)"
    exit 0
}

has_arg() {
    local param="${1}"
    local params="${args[*]}"

    # shortcuts for arguments
    [[ " ${params} " =~ " c " ]] && params=" ${params} composer "
    [[ " ${params} " =~ " g " ]] && params=" ${params} git "
    [[ " ${params} " =~ " l " ]] && params=" ${params} laravel "

    # shellcheck disable=SC2076
    if [[ " ${params} " =~ " ${param} " ]]; then
        return 0
    else
        return 1
    fi
}

run_chmod() {
    has_arg "chmod" || return 0

    info "Setting correct file and folder permissions..."

    test ! -d .git && failure "This is not a git repository root folder."

    find . -type d \
        ! -path "*/.ddev/*" \
        ! -path "*/.git/*" \
        ! -path "*/.idea/*" \
        ! -path "*/node_modules/*" \
        ! -path "*/vendor/*" \
        -exec chmod --changes 755 {} \;

    find . -type f \
        ! -path "*/.ddev/*" \
        ! -path "*/.git/*" \
        ! -path "*/.idea/*" \
        ! -path "*/node_modules/*" \
        ! -path "*/vendor/*" \
        ! -path "./artisan" \
        -exec chmod --changes 644 {} \;

    if has_arg "laravel"; then
        test -f artisan && chmod --changes 755 artisan
    fi

    info "Permissions have been set."
    exit 0
}

run_git_reset() {
    has_arg "git" || return 0
    has_arg "clean" || has_arg "reset" || return 0

    info "Running git clean -idX
    -i interactive,
    -d for removing directories,
    -X remove only files ignored by git."
    echo

    git clean -idX

    exit 0
}

run_laravel_pint() {
    has_arg "pint" || return 0

    test ! -f composer.json && failure "composer.json not found."

    local pint_package="laravel/pint"
    local pint_config="pint.json"
    local pint_preset=""

    if has_arg "force" || has_arg "revert"; then
        rm -f "${pint_config}"

        if has_arg "revert"; then
            if composer show "${pint_package}" >/dev/null 2>&1; then
                composer remove "${pint_package}" --dev
            fi

            info "Removed Laravel Pint from the project..."
            return 0
        fi
    fi

    info "Adding Laravel Pint to the project..."

    if ! composer show "${pint_package}" >/dev/null 2>&1 || has_arg "force"; then
        composer require "${pint_package}" --dev
    fi

    if has_arg "laravel"; then
        pint_preset='{"preset":"laravel"}'
    elif has_arg "psr12"; then
        pint_preset='{"preset":"psr12"}'
    elif has_arg "symfony"; then
        pint_preset='{"preset":"symfony"}'
    fi

    if [[ "${pint_preset}" != "" ]]; then
        local formatted_preset
        formatted_preset="$(jq --indent 4 <<< "${pint_preset}")"
        [[ "${formatted_preset}" != "" ]] && echo "${formatted_preset}" > "${pint_config}"
    fi

    info "Added Laravel Pint to the project."
    exit 0
}

run_laravel_upgrade() {
    has_arg "laravel" || return 0
    has_arg "upgrade" || return 0

    test ! -f artisan && failure "This is not a Laravel root folder."

    info "Upgrading Laravel structure..."

    # shellcheck disable=SC2119
    if ! confirm; then
        return 0
    fi

    local release
    release="$(curl -s https://api.github.com/repos/laravel/laravel/releases/latest)"
    local temp_folder
    temp_folder="/tmp/laravel-$(date +'%Y-%m-%d-%H-%M-%S')"
    local tarball_url
    tarball_url="$(echo "${release}" | jq -r ".tarball_url")"
    local tag_name
    tag_name="$(echo "${release}" | jq -r ".tag_name")"
    local archive_path="${temp_folder}.tar.gz"

    info "Using ${tag_name}"

    mkdir -p "${temp_folder}"
    wget --no-verbose "${tarball_url}" --output-document "${archive_path}"
    tar --extract --file "${archive_path}" --directory "${temp_folder}" --strip-components=1
    rm -f "${archive_path}"

    if [[ -f "${temp_folder}/artisan" ]]; then
        info "Replacing files..."

        cp --archive "${temp_folder}/." "${PWD}"
    else
        warning "The artisan file not found."
        ls -la "${temp_folder}"
    fi

    rm -rf "${temp_folder}"

    info "Done https://github.com/laravel/laravel/releases"
    exit 0
}

run_composer_install() {
    local check="${1:-true}"

    if ${check}; then
        has_arg "composer" || return 0
        ! has_arg "list" || return 0
    fi

    test ! -f composer.json && failure "composer.json not found."

    info "Checking composer dependencies..."
    composer validate

    if has_arg "force"; then
        info "Removing vendor directory..."
        rm -rf vendor
    fi

    if [[ ! -d vendor ]]; then
        composer install
        info "Installed composer dependencies."
    fi
}

run_composer_list() {
    has_arg "composer" || return 0
    has_arg "list" || return 0

    info "Recommendations for composer packages:"
    echo

    # shellcheck disable=SC2155
    local installed="$(composer show -N || true)"

    for item in "${!STUB_COMPOSER_PACKAGES[@]}"; do
        if echo "${installed}" | grep -qv "${item}"; then
            primary "composer require ${item}"
            warning "${STUB_COMPOSER_PACKAGES[${item}]}"
            echo
        fi
    done

    for dev_item in "${!STUB_COMPOSER_DEV_PACKAGES[@]}"; do
        if echo "${installed}" | grep -qv "${dev_item}"; then
            primary "composer require --dev ${dev_item}"
            warning "${STUB_COMPOSER_DEV_PACKAGES[${dev_item}]}"
            echo
        fi
    done
}

run_npm() {
    has_arg "npm" || return 0

    test ! -f package.json && failure "package.json not found."

    if has_arg "force"; then
        info "Removing node_modules directory..."
        rm -rf node_modules
        info "Removed node_modules directory."
    fi

    info "Adding .gitignore for assets..."

    patch --no-backup-if-mismatch --forward .gitignore --reject-file - <<< "${STUB_NPM_GITIGNORE}" || true

    if [[ ! -d node_modules ]]; then
        info "Installing npm..."
        npm install
    fi
}

run_laravel_general() {
    has_arg "laravel" || return 0

    test ! -f artisan && failure "This is not a Laravel root folder."

    if [[ ! -d vendor ]]; then
        run_composer_install false
    fi

    info "Checking .env file..."

    cp -n .env.example .env
    grep -qx "APP_KEY=" .env && php artisan key:generate

    info "Removing all caches..."

    if php artisan | grep -q "optimize:clear"; then
        php artisan optimize:clear
    fi

    if php artisan | grep -q "debugbar:clear"; then
        php artisan debugbar:clear
    fi
}

run_laravel_php_cs_fixer() {
    has_arg "laravel" || return 0
    has_arg "fixer" || return 0

    if has_arg "force" || has_arg "revert"; then
        info "Removing php-cs-fixer..."

        local clean_project_json
        clean_project_json="$(jq --indent 4 'del(
            .scripts["post-install-cmd"],
            .scripts["check-style"],
            .scripts["fix-style"]
        )' composer.json)"

        echo "${clean_project_json}" > composer.json

        rm -rf tools/php-cs-fixer
        rm -f app/Helpers/ComposerScripts.php

        info "php-cs-fixer is removed."

        if has_arg "revert"; then
            return 0
        fi
    fi

    info "Checking php-cs-fixer installation..."

    mkdir -p tools/php-cs-fixer
    test ! -f tools/php-cs-fixer/.gitignore && printf "/vendor\n.php-cs-fixer.cache\n.php-cs-fixer.php\n" > tools/php-cs-fixer/.gitignore
    test ! -f tools/php-cs-fixer/.php-cs-fixer.dist.php && echo "${STUB_FIXER_CONFIG}" > tools/php-cs-fixer/.php-cs-fixer.dist.php
    test ! -f tools/php-cs-fixer/composer.json && composer require --dev -d tools/php-cs-fixer \
        adamwojs/php-cs-fixer-phpdoc-force-fqcn friendsofphp/php-cs-fixer jubeki/laravel-code-style

    local tools_json
    tools_json="$(jq --indent 4 '.scripts += {
        "check-style": "@fix-style --diff --dry-run --stop-on-violation --using-cache=no",
        "fix-style": "php-cs-fixer fix -v --show-progress=dots"
    }' tools/php-cs-fixer/composer.json)"

    echo "${tools_json}" > tools/php-cs-fixer/composer.json

    local project_json
    project_json="$(jq --indent 4 '.scripts += {
        "post-install-cmd": ["App\\Helpers\\ComposerScripts::devModeOnly", "@composer install -d tools/php-cs-fixer"],
        "check-style": "@composer check-style -d tools/php-cs-fixer",
        "fix-style": "@composer fix-style -d tools/php-cs-fixer"
    }' composer.json)"

    echo "${project_json}" > composer.json

    mkdir -p app/Helpers
    test ! -f app/Helpers/ComposerScripts.php && echo "${STUB_HELPER_COMPOSER_SCRIPT}" > app/Helpers/ComposerScripts.php

    info "php-cs-fixer is installed."
}

run_laravel_ide_helper() {
    has_arg "laravel" || return 0
    has_arg "ide" || has_arg "ide2" || return 0

    info "Changing PHPDoc types in the ./vendor folder for autocomplete..."

    # autocomplete for user
    sed -i 's/@return \\Illuminate\\Contracts\\Auth\\Authenticatable|null/@return \\App\\Models\\User/g' \
        vendor/laravel/framework/src/Illuminate/Contracts/Auth/Guard.php

    # remove null from request
    sed -i 's/@return \\Illuminate\\Http\\Request|string|array|null/@return \\Illuminate\\Http\\Request|string|array/g' \
        vendor/laravel/framework/src/Illuminate/Foundation/helpers.php

    # autocomplete for paginate method
    sed -i 's/@return \\Illuminate\\Contracts\\Pagination\\LengthAwarePaginator/@return \\Illuminate\\Pagination\\LengthAwarePaginator/g' \
        vendor/laravel/framework/src/Illuminate/Database/Eloquent/Builder.php

    info "Applying IDE Helper..."

    if php artisan | grep -q "ide-helper:generate"; then
        if has_arg "ide2"; then
            php artisan ide-helper:generate && \
            touch database/ide-helper-models.sqlite.tmp && \
            DB_CONNECTION=sqlite \
            DB_DATABASE=database/ide-helper-models.sqlite.tmp \
            bash -c 'php artisan migrate && php artisan ide-helper:models -N' && \
            php artisan ide-helper:meta && \
            rm database/ide-helper-models.sqlite.tmp
        else
            php artisan ide-helper:generate && \
            php artisan ide-helper:meta && \
            php artisan ide-helper:models -N
        fi
    else
        info "Only some autocomplete has been added."
        warning "If you're using the Laravel Idea plugin that's fine (run Ctrl+Shift+,)
Otherwise: composer require --dev barryvdh/laravel-ide-helper"
    fi
}

run_laravel_path() {
    has_arg "laravel" || return 0
    has_arg "path" || return 0

    if has_arg "force" || has_arg "revert"; then
        rm -f app/Helpers/Path.php
        rm -f app/Helpers/HasPath.php

        if has_arg "revert"; then
            info "Removed path() helper from the project..."
            return 0
        fi
    fi

    info "Adding path() helper to the project..."

    mkdir -p app/Helpers
    test ! -f app/Helpers/Path.php && echo "${STUB_HELPER_PATH}" > app/Helpers/Path.php
    test ! -f app/Helpers/HasPath.php && echo "${STUB_HELPER_PATH_TRAIT}" > app/Helpers/HasPath.php

    info "Added path() helper to the project..."
}

run_laravel_slack() {
    has_arg "laravel" || return 0
    has_arg "slack" || return 0

    local slack_package="laravel/slack-notification-channel"
    local slack_report_class="app/Notifications/SlackReport.php"

    if has_arg "revert"; then
        info "Removing Slack integration..."
        rm -f "${slack_report_class}"
        patch --no-backup-if-mismatch --forward --reverse config/logging.php --reject-file - <<< "${STUB_SLACK_CONFIG_LOGGING}" || true
        patch --no-backup-if-mismatch --forward --reverse .env.example --reject-file - <<< "${STUB_SLACK_CONFIG_ENV}" || true
        patch --no-backup-if-mismatch --forward --reverse app/Exceptions/Handler.php --reject-file - <<< "${STUB_SLACK_HANDLER}" || true

        if composer show "${slack_package}" >/dev/null 2>&1; then
            composer remove "${slack_package}"
        fi

        info "Removed Slack integration."

        return 0
    fi

    if has_arg "force"; then
        rm -f "${slack_report_class}"
    fi

    info "Adding Slack integration..."

    patch --no-backup-if-mismatch --forward config/logging.php --reject-file - <<< "${STUB_SLACK_CONFIG_LOGGING}" || true
    patch --no-backup-if-mismatch --forward .env.example --reject-file - <<< "${STUB_SLACK_CONFIG_ENV}" || true
    patch --no-backup-if-mismatch --forward .env --reject-file - <<< "${STUB_SLACK_CONFIG_ENV}" || true
    patch --no-backup-if-mismatch --forward app/Exceptions/Handler.php --reject-file - <<< "${STUB_SLACK_HANDLER}" || true

    if ! composer show "${slack_package}" >/dev/null 2>&1 || has_arg "force"; then
        composer require "${slack_package}"
    fi

    mkdir -p app/Notifications
    test ! -f "${slack_report_class}" && echo "${STUB_SLACK_REPORT}" > "${slack_report_class}"

    info "Added Slack integration..."
}

run_laravel_sqlite() {
    has_arg "laravel" || return 0
    has_arg "sqlite" || return 0

    if has_arg "force"; then
        info "Removing sqlite database..."
        rm -f database/database.sqlite
        info "Removed sqlite database."
    fi

    info "Creating sqlite database..."
    touch database/database.sqlite
    sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/g' .env
    sed -i 's/^DB_DATABASE/#DB_DATABASE/g' .env
    php artisan migrate
}

run_laravel_stub() {
    has_arg "laravel" || return 0
    has_arg "stub" || return 0

    if has_arg "force" || has_arg "revert"; then
        rm -f stubs/test.stub
        rm -f stubs/test.unit.stub

        if has_arg "revert"; then
            info "Removed stubs from the project..."
            return 0
        fi
    fi

    info "Adding stubs to the project..."

    mkdir -p stubs
    test ! -f stubs/test.stub && echo "${STUB_FEATURE_TEST}" > stubs/test.stub
    test ! -f stubs/test.unit.stub && echo "${STUB_UNIT_TEST}" > stubs/test.unit.stub

    info "Added stubs to the project..."
}

#}}}

main "${@}"
