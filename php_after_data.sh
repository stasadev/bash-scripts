#!/usr/bin/env bash
#
# Author: Stanislav Zhuk <stanislav.zhuk.work@gmail.com>
#

STUB_FEATURE_TEST=$(cat <<-"STUB"
<?php

namespace {{ namespace }};

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class {{ class }} extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function feature()
    {
        //
    }
}
STUB
)

STUB_UNIT_TEST=$(cat <<-"STUB"
<?php

namespace {{ namespace }};

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class {{ class }} extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function unit()
    {
        //
    }
}
STUB
)

STUB_HELPER_PATH=$(cat <<-"STUB"
<?php

namespace App\Helpers;

use Illuminate\Database\Eloquent\Model;

class Path
{
    protected Model $model;
    protected string $table;

    public function __construct(Model $model)
    {
        $this->model = $model;
        $this->table = $model->getTable();
    }

    protected function prepare(string $route, ?string $nested = null): string
    {
        return $this->table.($nested ? '.'.$nested : '').'.'.$route;
    }

    public function index(?string $nested = null): string
    {
        return route($this->prepare('index', $nested), $this->model);
    }

    public function create(?string $nested = null): string
    {
        return route($this->prepare('create', $nested), $this->model);
    }

    public function store(?string $nested = null): string
    {
        return route($this->prepare('store', $nested), $this->model);
    }

    public function show(): string
    {
        return route($this->prepare('show'), $this->model);
    }

    public function edit(): string
    {
        return route($this->prepare('edit'), $this->model);
    }

    public function update(): string
    {
        return route($this->prepare('update'), $this->model);
    }

    public function destroy(): string
    {
        return route($this->prepare('destroy'), $this->model);
    }

    public function __toString()
    {
        return $this->show();
    }
}
STUB
)

STUB_HELPER_PATH_TRAIT=$(cat <<-"STUB"
<?php

namespace App\Helpers;

trait HasPath
{
    public function path(): Path
    {
        return new Path($this);
    }
}
STUB
)

STUB_HELPER_COMPOSER_SCRIPT=$(cat <<-"STUB"
<?php

namespace App\Helpers;

use Composer\Script\Event;

class ComposerScripts
{
    /**
     * Run scripts that follow only if dev packages are installed.
     *
     * @param  \Composer\Script\Event  $event
     */
    public static function devModeOnly(Event $event)
    {
        if (! $event->isDevMode()) {
            $event->stopPropagation();
            echo "Skipping {$event->getName()} as this is a non-dev installation.\n";
        }
    }
}
STUB
)

STUB_FIXER_CONFIG=$(cat <<-"STUB"
<?php
require __DIR__ . '/vendor/autoload.php';

$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__ . '/../../')
    ->exclude([
        'bootstrap/cache',
        'database/migrations',
        'node_modules',
        'storage',
        'tools',
        'vendor',
    ])
    ->name('*.php')
    ->notName([
        '*.blade.php',
        '_ide_helper*',
    ])
    ->ignoreDotFiles(true)
    ->ignoreVCS(true);

$rules = [
    // sets
    '@Laravel' => true,
    '@Laravel:risky' => true,
    '@PSR12' => true,
    // regular
    'backtick_to_shell_exec' => true,
    'blank_line_before_statement' => [
        'statements' => [
            'if',
            'declare',
            'switch',
            'throw',
            'try',
            'return',
        ],
    ],
    'braces' => true,
    'class_reference_name_casing' => true,
    'combine_consecutive_issets' => true,
    'control_structure_continuation_position' => true,
    'date_time_create_from_format_call' => true,
    'declare_parentheses' => true,
    'echo_tag_syntax' => true,
    'empty_loop_condition' => true,
    'explicit_indirect_variable' => true,
    'explicit_string_variable' => true,
    'linebreak_after_opening_tag' => true,
    'method_chaining_indentation' => true,
    'multiline_comment_opening_closing' => true,
    'new_with_braces' => false,
    'no_useless_else' => true,
    'no_unneeded_import_alias' => true,
    'nullable_type_declaration_for_default_null_value' => true,
    'php_unit_method_casing' => [
        'case' => 'snake_case',
    ],
    'semicolon_after_instruction' => true,
    'simple_to_complex_string_variable' => true,
    'simplified_if_return' => true,
    'single_line_comment_spacing' => true,
    'single_space_after_construct' => true,
    'single_trait_insert_per_statement' => false,
    // risky
    'array_push' => true,
    'dir_constant' => true,
    'ereg_to_preg' => true,
    'modernize_types_casting' => true,
    'no_alias_functions' => true,
    'no_homoglyph_names' => true,
    'no_unreachable_default_argument_value' => true,
    'psr_autoloading' => true,
    'self_accessor' => true,
    'strict_param' => true,
    'string_line_ending' => true,
    'ternary_to_elvis_operator' => true,
    // custom
    'AdamWojs/phpdoc_force_fqcn_fixer' => true,
];

return (new Jubeki\LaravelCodeStyle\Config())
    ->setFinder($finder)
    ->registerCustomFixers([
        new AdamWojs\PhpCsFixerPhpdocForceFQCN\Fixer\Phpdoc\ForceFQCNFixer(),
    ])
    ->setRules($rules)
    ->setRiskyAllowed(true)
    ->setCacheFile(__DIR__ . '/.php-cs-fixer.cache');
STUB
)

declare -A STUB_COMPOSER_PACKAGES=(
     ["browner12/helpers"]="This is a helpers package that provides some built in helpers, and also provides an Artisan generator to quickly create your own custom helpers."
)
declare -A STUB_COMPOSER_DEV_PACKAGES=(
     ["barryvdh/laravel-debugbar"]="This is a package to integrate PHP Debug Bar with Laravel.
Run this after installation:
mkdir -p storage/debugbar && bash -c 'printf \"*\n!.gitignore\n\" > storage/debugbar/.gitignore'"
     ["barryvdh/laravel-ide-helper"]="This package generates helper files that enable your IDE to provide accurate autocompletion."
     ["beyondcode/laravel-query-detector"]="Laravel N+1 Query Detector."
     ["ergebnis/composer-normalize"]="[GLOBAL] Provides a composer plugin for normalizing composer.json."
     ["sven/artisan-view"]="Manage your views in Laravel projects through artisan."
)

STUB_NPM_GITIGNORE=$(cat <<-"STUB"
@@ -1,3 +1,6 @@
 /node_modules
+/public/css
 /public/hot
+/public/js
+/public/mix-manifest.json
 /public/storage
STUB
)

STUB_SLACK_CONFIG_ENV=$(cat <<-"STUB"
@@ -7,2 +7,6 @@
 LOG_CHANNEL=stack
+LOG_SLACK_WEBHOOK_URL=
+LOG_SLACK_CHANNEL=
+LOG_SLACK_EMOJI=:boom:
+LOG_SLACK_CACHE_SECONDS=0
STUB
)

STUB_SLACK_HANDLER_LARAVEL_8_9_10=$(cat <<-"STUB"
@@ -24,7 +24,7 @@
     public function register(): void
     {
         $this->reportable(function (Throwable $e) {
-            //
+            \Stasadev\SlackNotifier\Facades\SlackNotifier::send($e);
         });
     }
 }
STUB
)

STUB_SLACK_HANDLER_LARAVEL_57_58_6_7=$(cat <<-"STUB"
@@ -36,6 +36,10 @@
      */
     public function report(Throwable $exception)
     {
+        if ($this->shouldReport($exception)) {
+            \Stasadev\SlackNotifier\Facades\SlackNotifier::send($exception);
+        }
+
         parent::report($exception);
     }
STUB
)
