#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Description
# -----------
#
#  Completion script for Kamal deployment tool (https://kamal-deploy.org/).
#
# ------------------------------------------------------------------------------

_init_completion() {
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  words=("${COMP_WORDS[@]}")
  cword="${COMP_CWORD}"
  return 0
}

# Helper function to generate completions for common options
_kamal_common_options() {
  local opts=(
    "-v" "--verbose" "--no-verbose" "--skip-verbose"
    "-q" "--quiet" "--no-quiet" "--skip-quiet"
    "--version"
    "-p" "--primary" "--no-primary" "--skip-primary"
    "-h" "--hosts"
    "-r" "--roles"
    "-c" "--config-file"
    "-d" "--destination"
    "-H" "--skip-hooks"
  )
  COMPREPLY+=($(compgen -W "${opts[*]}" -- "$cur"))
}

# Main completion function
_kamal_complete() {
  local cur prev words cword
  _init_completion

  # Top-level commands
  local commands=(
    "accessory" "app" "audit" "build" "config" "deploy" "details" "docs"
    "help" "init" "lock" "proxy" "prune" "redeploy" "registry" "remove"
    "rollback" "secrets" "server" "setup" "upgrade" "version"
  )

  # Handle specific option arguments
  case "$prev" in
  -c | --config-file)
    _filedir
    return
    ;;
  --version | -h | --hosts | -r | --roles | -d | --destination | -m | --message)
    # These options expect arguments, but no specific completions
    return
    ;;
  esac

  # If we're at top level, suggest commands
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=($(compgen -W "${commands[*]}" -- "$cur"))
    return
  fi

  # Handle subcommands
  local command="${words[1]}"
  case "$command" in
  accessory)
    local subcmds=("boot" "details" "exec" "help" "logs" "reboot" "remove" "restart" "start" "stop" "upgrade")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    boot | details | logs | reboot | remove | restart | start | stop)
      if [[ $cword -eq 3 ]]; then
        COMPREPLY=($(compgen -W "all db redis search" -- "$cur"))
      else
        _kamal_common_options
      fi
      ;;
    exec)
      if [[ $cword -eq 3 ]]; then
        COMPREPLY=($(compgen -W "all db redis search" -- "$cur"))
      fi
      ;;
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  app)
    local subcmds=("boot" "containers" "details" "exec" "help" "images" "logs" "remove" "stale_containers" "start" "stop" "version")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  build)
    local subcmds=("create" "deliver" "details" "dev" "help" "pull" "push" "remove")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  docs)
    local sections=("boot" "alias" "logging" "env" "builder" "registry" "ssh" "sshkit" "role" "accessory" "servers" "proxy")
    COMPREPLY=($(compgen -W "${sections[*]}" -- "$cur"))
    ;;

  help)
    COMPREPLY=($(compgen -W "${commands[*]}" -- "$cur"))
    ;;

  lock)
    local subcmds=("acquire" "help" "release" "status")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    acquire)
      COMPREPLY=($(compgen -W "-m --message" -- "$cur"))
      ;;
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  proxy)
    local subcmds=("boot" "boot_config" "details" "help" "logs" "reboot" "remove" "restart" "start" "stop")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    boot_config)
      if [[ $cword -eq 3 ]]; then
        COMPREPLY=($(compgen -W "set get reset" -- "$cur"))
      fi
      ;;
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  prune)
    local subcmds=("all" "containers" "help" "images")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  registry)
    local subcmds=("help" "login" "logout")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  secrets)
    local subcmds=("extract" "fetch" "help" "print")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    fetch)
      COMPREPLY=($(compgen -W "-a --adapter" -- "$cur"))
      ;;
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  server)
    local subcmds=("bootstrap" "exec" "help")

    if [[ $cword -eq 2 ]]; then
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      return
    fi

    local subcmd="${words[2]}"
    case "$subcmd" in
    help)
      COMPREPLY=($(compgen -W "${subcmds[*]}" -- "$cur"))
      ;;
    *)
      _kamal_common_options
      ;;
    esac
    ;;

  deploy | redeploy)
    COMPREPLY=($(compgen -W "-P --skip-push" -- "$cur"))
    _kamal_common_options
    ;;

  remove)
    COMPREPLY=($(compgen -W "-y --confirmed --no-confirmed --skip-confirmed" -- "$cur"))
    _kamal_common_options
    ;;

  upgrade)
    COMPREPLY=($(compgen -W "-y --confirmed --no-confirmed --skip-confirmed --rolling --no-rolling --skip-rolling" -- "$cur"))
    _kamal_common_options
    ;;

  init)
    COMPREPLY=($(compgen -W "--bundle --no-bundle --skip-bundle" -- "$cur"))
    _kamal_common_options
    ;;

  *)
    _kamal_common_options
    ;;
  esac
}

# Register the completion function
complete -F _kamal_complete kamal
