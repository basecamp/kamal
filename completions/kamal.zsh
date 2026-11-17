#compdef kamal
# ------------------------------------------------------------------------------
# Description
# -----------
#
#  Completion script for Kamal deployment tool (https://kamal-deploy.org/).
#
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------

# Helper function to handle common subcommand patterns
_kamal_handle_subcommands() {
  local cmd_var=$1
  local cmd_list=$2
  local simple_cmds=$3
  local special_cases=$4

  _arguments -C \
    $common_options \
    "1: :{_describe \"$cmd_var commands\" $cmd_list}" \
    '*:: :->subcommand'

  case "$state" in
    (subcommand)
      local cmd=$words[1]
      # Handle help command consistently across all subcommand groups
      if [[ "$cmd" == "help" ]]; then
        _arguments "1:$cmd_var command:(\$$cmd_list)"
        return
      fi

      # Check if command is in the simple commands list
      if [[ " $simple_cmds " =~ " $cmd " ]]; then
        _arguments $common_options
        return
      fi

      # Special cases handling
      if [[ -n "$special_cases" ]]; then
        eval "$special_cases"
      fi
      ;;
  esac
}

_kamal() {
  local context state state_descr line curcontext="$curcontext"
  typeset -A opt_args

  local -a common_options
  common_options=(
    '(-v --verbose )'{-v,--verbose}'[Detailed logging]'
    '(--no-verbose --skip-verbose)'{--no-verbose,--skip-verbose}'[No detailed logging]'
    '(-q --quiet --no-quiet --skip-quiet)'{-q,--quiet}'[Minimal logging]'
    '(-q --quiet --no-quiet --skip-quiet)'{--no-quiet,--skip-quiet}'[No minimal logging]'
    '--version=[Run commands against a specific app version]:version'
    '(-p --primary --no-primary --skip-primary)'{-p,--primary}'[Run commands only on primary host instead of all]'
    '(-p --primary --no-primary --skip-primary)'{--no-primary,--skip-primary}'[Do not run commands only on primary host]'
    '(-h --hosts)'{-h,--hosts=}'[Run commands on these hosts instead of all]:hosts'
    '(-r --roles)'{-r,--roles=}'[Run commands on these roles instead of all]:roles'
    '(-c --config-file)'{-c,--config-file=}'[Path to config file]:config file:_files'
    '(-d --destination)'{-d,--destination=}'[Specify destination to be used for config file]:destination'
    '(-H --skip-hooks)'{-H,--skip-hooks}'[Do not run hooks]'
  )

  local ret=1

  _arguments -C \
    $common_options \
    '1: :_kamal_commands' \
    '*:: :->command' && ret=0

  case "$state" in
    (command)
      case $words[1] in
        (accessory)
          _kamal_accessory && ret=0
          ;;
        (app)
          _kamal_app && ret=0
          ;;
        (audit)
          _arguments $common_options && ret=0
          ;;
        (build)
          _kamal_build && ret=0
          ;;
        (config)
          _arguments $common_options && ret=0
          ;;
        (deploy)
          _arguments $common_options \
            '(-P --skip-push)'{-P,--skip-push}'[Skip image build and push]' && ret=0
          ;;
        (details)
          _arguments $common_options && ret=0
          ;;
        (docs)
          _kamal_docs && ret=0
          ;;
        (help)
          _kamal_help && ret=0
          ;;
        (init)
          _arguments $common_options \
            '--bundle[Add Kamal to the Gemfile and create a bin/kamal binstub]' \
            '--no-bundle[Do not add Kamal to the Gemfile]' \
            '--skip-bundle[Skip adding Kamal to the Gemfile]' && ret=0
          ;;
        (lock)
          _kamal_lock && ret=0
          ;;
        (proxy)
          _kamal_proxy && ret=0
          ;;
        (prune)
          _kamal_prune && ret=0
          ;;
        (redeploy)
          _arguments $common_options \
            '(-P --skip-push)'{-P,--skip-push}'[Skip image build and push]' && ret=0
          ;;
        (registry)
          _kamal_registry && ret=0
          ;;
        (remove)
          _arguments $common_options \
            '(-y --confirmed --no-confirmed --skip-confirmed)'{-y,--confirmed}'[Proceed without confirmation question]' \
            '(-y --confirmed --no-confirmed --skip-confirmed)'{--no-confirmed,--skip-confirmed}'[Do not proceed without confirmation]' && ret=0
          ;;
        (rollback)
          _arguments $common_options '1:version' && ret=0
          ;;
        (secrets)
          _kamal_secrets && ret=0
          ;;
        (server)
          _kamal_server && ret=0
          ;;
        (setup)
          _arguments $common_options \
            '(-P --skip-push)'{-P,--skip-push}'[Skip image build and push]' && ret=0
          ;;
        (upgrade)
          _arguments $common_options \
            '(-y --confirmed --no-confirmed --skip-confirmed)'{-y,--confirmed}'[Proceed without confirmation question]' \
            '(-y --confirmed --no-confirmed --skip-confirmed)'{--no-confirmed,--skip-confirmed}'[Do not proceed without confirmation]' \
            '--rolling[Upgrade one host at a time]' \
            '--no-rolling[Do not upgrade one host at a time]' \
            '--skip-rolling[Skip upgrading one host at a time]' && ret=0
          ;;
        (version)
          _arguments $common_options && ret=0
          ;;
      esac
      ;;
  esac

  return ret
}

(( $+functions[_kamal_commands] )) ||
_kamal_commands() {
  local -a commands=(
    'accessory:Manage accessories (db/redis/search)'
    'app:Manage application'
    'audit:Show audit log from servers'
    'build:Build application image'
    'config:Show combined config (including secrets!)'
    'deploy:Deploy app to servers'
    'details:Show details about all containers'
    'docs:Show Kamal configuration documentation'
    'help:Describe available commands or one specific command'
    'init:Create config stub in config/deploy.yml and secrets stub in .kamal'
    'lock:Manage the deploy lock'
    'proxy:Manage kamal-proxy'
    'prune:Prune old application images and containers'
    'redeploy:Deploy app to servers without bootstrapping servers, starting kamal-proxy, pruning, and registry login'
    'registry:Login and -out of the image registry'
    'remove:Remove kamal-proxy, app, accessories, and registry session from servers'
    'rollback:Rollback app to VERSION'
    'secrets:Helpers for extracting secrets'
    'server:Bootstrap servers with curl and Docker'
    'setup:Setup all accessories, push the env, and deploy app to servers'
    'upgrade:Upgrade from Kamal 1.x to 2.0'
    'version:Show Kamal version'
  )

  _describe -t commands 'kamal commands' commands
}

(( $+functions[_kamal_accessory] )) ||
_kamal_accessory() {
  local -a accessory_commands=(
    'boot:Boot new accessory service on host'
    'details:Show details about accessory on host'
    'exec:Execute a custom command on servers within the accessory container'
    'help:Describe subcommands or one specific subcommand'
    'logs:Show log lines from accessory on host'
    'reboot:Reboot existing accessory on host'
    'remove:Remove accessory container, image and data directory'
    'restart:Restart existing accessory container on host'
    'start:Start existing accessory container on host'
    'stop:Stop existing accessory container on host'
    'upgrade:Upgrade accessories from Kamal 1.x to 2.0'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "accessory commands" accessory_commands}' \
    '*:: :->accessory_command'

  case "$state" in
    (accessory_command)
      case $words[1] in
        (boot|details|logs|reboot|remove|restart|start|stop)
          _arguments $common_options \
            '1:accessory name:(all db redis search)'
          ;;
        (exec)
          _arguments $common_options \
            '1:accessory name:(all db redis search)' \
            '*:command'
          ;;
        (help)
          _arguments \
            '1:accessory command:($accessory_commands)'
          ;;
        (upgrade)
          _arguments $common_options
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_app] )) ||
_kamal_app() {
  local -a app_commands=(
    'boot:Boot app on servers (or reboot app if already running)'
    'containers:Show app containers on servers'
    'details:Show details about app containers'
    'exec:Execute a custom command on servers within the app container'
    'help:Describe subcommands or one specific subcommand'
    'images:Show app images on servers'
    'logs:Show log lines from app on servers'
    'remove:Remove app containers and images from servers'
    'stale_containers:Detect app stale containers'
    'start:Start existing app container on servers'
    'stop:Stop app container on servers'
    'version:Show app version currently running on servers'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "app commands" app_commands}' \
    '*:: :->app_command'

  case "$state" in
    (app_command)
      case $words[1] in
        (boot|containers|details|images|logs|remove|stale_containers|start|stop|version)
          _arguments $common_options
          ;;
        (exec)
          _arguments $common_options \
            '*:command'
          ;;
        (help)
          _arguments \
            '1:app command:($app_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_build] )) ||
_kamal_build() {
  local -a build_commands=(
    'create:Create a build setup'
    'deliver:Build app and push app image to registry then pull image on servers'
    'details:Show build setup'
    'dev:Build using the working directory, tag it as dirty, and pull it on servers'
    'help:Describe subcommands or one specific subcommand'
    'pull:Pull app image from registry onto servers'
    'push:Build and push app image to registry'
    'remove:Remove build setup'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "build commands" build_commands}' \
    '*:: :->build_command'

  case "$state" in
    (build_command)
      case $words[1] in
        (create|deliver|details|dev|pull|push|remove)
          _arguments $common_options
          ;;
        (help)
          _arguments \
            '1:build command:($build_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_docs] )) ||
_kamal_docs() {
  local -a doc_sections=(
    'boot'
    'alias'
    'logging'
    'env'
    'builder'
    'registry'
    'ssh'
    'sshkit'
    'role'
    'accessory'
    'servers'
    'proxy'
  )

  _arguments \
    $common_options \
    '1:section:{_describe "documentation sections" doc_sections}'
}

(( $+functions[_kamal_help] )) ||
_kamal_help() {
  _arguments '1:command:_kamal_commands'
}

(( $+functions[_kamal_lock] )) ||
_kamal_lock() {
  local -a lock_commands=(
    'acquire:Acquire the deploy lock'
    'help:Describe subcommands or one specific subcommand'
    'release:Release the deploy lock'
    'status:Report lock status'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "lock commands" lock_commands}' \
    '*:: :->lock_command'

  case "$state" in
    (lock_command)
      case $words[1] in
        (acquire)
          _arguments $common_options \
            '(-m --message)'{-m,--message=}'[Lock message]:message'
          ;;
        (release|status)
          _arguments $common_options
          ;;
        (help)
          _arguments \
            '1:lock command:($lock_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_proxy] )) ||
_kamal_proxy() {
  local -a proxy_commands=(
    'boot:Boot proxy on servers'
    'boot_config:Manage kamal-proxy boot configuration'
    'details:Show details about proxy container from servers'
    'help:Describe subcommands or one specific subcommand'
    'logs:Show log lines from proxy on servers'
    'reboot:Reboot proxy on servers'
    'remove:Remove proxy container and image from servers'
    'restart:Restart existing proxy container on servers'
    'start:Start existing proxy container on servers'
    'stop:Stop existing proxy container on servers'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "proxy commands" proxy_commands}' \
    '*:: :->proxy_command'

  case "$state" in
    (proxy_command)
      case $words[1] in
        (boot|details|logs|reboot|remove|restart|start|stop)
          _arguments $common_options
          ;;
        (boot_config)
          _arguments $common_options \
            '1:action:(set get reset)'
          ;;
        (help)
          _arguments \
            '1:proxy command:($proxy_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_prune] )) ||
_kamal_prune() {
  local -a prune_commands=(
    'all:Prune unused images and stopped containers'
    'containers:Prune all stopped containers, except the last n (default 5)'
    'help:Describe subcommands or one specific subcommand'
    'images:Prune unused images'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "prune commands" prune_commands}' \
    '*:: :->prune_command'

  case "$state" in
    (prune_command)
      case $words[1] in
        (all|containers|images)
          _arguments $common_options
          ;;
        (help)
          _arguments \
            '1:prune command:($prune_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_registry] )) ||
_kamal_registry() {
  local -a registry_commands=(
    'help:Describe subcommands or one specific subcommand'
    'login:Log in to registry locally and remotely'
    'logout:Log out of registry locally and remotely'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "registry commands" registry_commands}' \
    '*:: :->registry_command'

  case "$state" in
    (registry_command)
      case $words[1] in
        (login|logout)
          _arguments $common_options
          ;;
        (help)
          _arguments \
            '1:registry command:($registry_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_secrets] )) ||
_kamal_secrets() {
  local -a secrets_commands=(
    'extract:Extract a single secret from the secrets'
    'fetch:Fetch secrets from a vault'
    'help:Describe subcommands or one specific subcommand'
    'print:Print the secrets (for debugging)'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "secrets commands" secrets_commands}' \
    '*:: :->secrets_command'

  case "$state" in
    (secrets_command)
      case $words[1] in
        (extract|print)
          _arguments $common_options
          ;;
        (fetch)
          _arguments $common_options \
            '(-a --adapter)'{-a,--adapter=}'[Adapter to use]:adapter' \
            '*:secrets'
          ;;
        (help)
          _arguments \
            '1:secrets command:($secrets_commands)'
          ;;
      esac
      ;;
  esac
}

(( $+functions[_kamal_server] )) ||
_kamal_server() {
  local -a server_commands=(
    'bootstrap:Set up Docker to run Kamal apps' 
    'exec:Run a custom command on the server'
    'help:Describe subcommands or one specific subcommand'
  )

  _arguments -C \
    $common_options \
    '1: :{_describe "server commands" server_commands}' \
    '*:: :->server_command'

  case "$state" in
    (server_command)
      case $words[1] in
        (bootstrap)
          _arguments $common_options
          ;;
        (exec)
          _arguments $common_options \
            '*:command'
          ;;
        (help)
          _arguments \
            '1:server command:($server_commands)'
          ;;
      esac
      ;;
  esac
}

_kamal "$@"
