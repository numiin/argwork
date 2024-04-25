#!/bin/bash

__argwork_one() {
  local index var="$2"

  case "$1" in
    .) index="$__argwork_counter" ;;
    *) index="$1" ;;
  esac

  if [[ "$index" != '_' && "$var" != '_' ]]
  then
    eval "$var='${COMP_WORDS[$(($index + 1))]}'"
  fi

  case "$index" in
    _)
      if [[ ! -v __argwork_optional_arg_vars[$var] ]]
      then
        __argwork_optional_param_count=$(($__argwork_optional_param_count + 1))
        __argwork_optional_arg_vars["$var"]="$var"
      fi
      index="$var"
      ;;
    *)
      if (($__argwork_positional_param_count < $index))
      then
        __argwork_positional_param_count="$index"
      fi
      __argwork_positional_arg_vars[$index]="$var"
      ;;
  esac

  shift 2

  local subcommand
  if [[ "$1" == '--' ]]
  then
    shift
    subcommand="$1"
  fi

  for param in "$@"
  do
    if [[ "$param" == '::' ]]
    then
      shift
      break
    else
      shift
    fi
  done

  local spec="$1";
  shift
  case "$spec" in
    from)
      __argwork_lookup_types["$index"]='from'
      __argwork_lookup_values["$index"]="$1"
      ;;
    here)
      local arg_list=(${@:1})
      __argwork_lookup_types["$index"]='opts'
      __argwork_lookup_values["$index"]=$(IFS=, ; echo "${arg_list[*]}")
      ;;
    shell)
      __argwork_lookup_types["$index"]='shell'
      __argwork_lookup_values["$index"]="$1"
      ;;
    cmd)
      __argwork_lookup_types["$index"]='cmd'
      __argwork_lookup_values["$index"]="$1"
      eval "__argwork_command_args__$index=(${@:2})"
      eval "__argwork_command_args__${index}_len=$(( ${#@} - 1 ))"
      ;;
    dir)
      __argwork_lookup_types["$index"]='dir'
      __argwork_lookup_values["$index"]='[/path/to/directory]'
      ;;
    file)
      __argwork_lookup_types["$index"]='file'
      __argwork_lookup_values["$index"]='[/path/to/file]'
      ;;
    *)
      ;;
  esac

  if [[ ! -z "$subcommand" ]]
  then
    if [[ $(type -t ${subcommand}__${!var}) == function ]]
    then
      eval "${subcommand}__${!var}"
    fi
  fi
}

__argwork_one_help() {
  local index var="$2"

  case "$1" in
    .) index="$__argwork_counter" ;;
    *) index="$1" ;;
  esac

  if [[ "$index" != '_' && "$var" != '_' ]]
  then
    eval "$var='${COMP_WORDS[$(($index + 1))]}'"
  fi

  case "$index" in
    _)
      >&2 printf " $(tput setaf 13)($(tput setaf 5)$var$(tput setaf 13))$(tput sgr0)"
      ;;
    *)
      >&2 printf " $(tput setaf 238)[$(tput setaf 11)$index$(tput setaf 238):$(tput setaf 7)$var$(tput setaf 238)]$(tput sgr0)"
      ;;
  esac

  shift 2

  local subcommand
  if [[ "$1" == '--' ]]
  then
    shift
    subcommand="$1"
    for param in "$@"
    do
      if [[ "$param" == '::' ]]
      then
        shift
        break
      else
        shift
      fi
    done

    local spec="$1";
    shift
    case "$spec" in
      here)
        if [[ ! -z "$subcommand" ]]
        then
          >&2 echo
          __argwork_help_indent+=4
          __argwork_counter+=1
          for switch in "$@"
          do
            if [[ $(type -t ${subcommand}__${switch}) == function ]]
            then
              >&2 printf "%${__argwork_help_indent}s"
              local save_counter="$__argwork_counter"
              >&2 printf "$(tput setaf 3)$switch$(tput sgr0)"
              >&2 printf "%$(( 10 - ${#switch} ))s"
              eval "${subcommand}__${switch}"
              __argwork_counter="$save_counter"
              >&2 echo
            fi
          done
          __argwork_help_indent+=-4
        fi
        ;;
      *)
        ;;
    esac
  fi
}

__argwork_script_name_to_path() {
  echo "$1"
}

__argwork_complete() {
  # Optionals consist of three parts and are specifired like <param>:<value>, i.e. 3 components
  if [[ $COMP_CWORD -gt $(($__argwork_positional_param_count + $__argwork_optional_param_count * 3 + 1)) ]]
  then
    return
  fi

  local sector=POSITIONAL
  if [[ $COMP_CWORD -gt $(( $__argwork_positional_param_count + 1 )) ]]
  then
    sector=OPTIONAL
  fi

  local key
  local key_shift=0
  case "$sector" in
    POSITIONAL)
      key="$(($COMP_CWORD - 1))"
      ;;
    OPTIONAL)
      if [[ "${COMP_WORDS[$COMP_CWORD]}" == ':' ]]
      then
        key="${COMP_WORDS[$(($COMP_CWORD - 1))]}"
        key_shift=1
        if [[ -z "$key" || ! -v __argwork_optional_arg_vars[$key] ]]; then return; fi
      elif [[ "${COMP_WORDS[$(($COMP_CWORD - 1))]}" == ':' ]]
      then
        key="${COMP_WORDS[$(($COMP_CWORD - 2))]}"
        key_shift=0
        if [[ -z "$key" || ! -v __argwork_optional_arg_vars[$key] ]]; then return; fi
      else
        COMPREPLY=($(compgen -W "$(printf "%s\n" "${__argwork_optional_arg_vars[@]/%/:}")" -- "${COMP_WORDS[$COMP_CWORD]}"))
        return
      fi
      ;;
  esac

  local word_index=$(($COMP_CWORD + $key_shift))

  local prefix=()
  local visited_pattern # pattern for excluding argument value up to a comma (used in list completion)
  local word="${COMP_WORDS[$word_index]}"
  local comp_word="${word}"
  if [[ "$word" == *,* ]]
  then
    comp_word="${word##*,}"
    prefix=( -P "${word%,*}," )
    IFS=, ; local visited=( $(echo "$word") )
    visited_pattern=$(IFS='|'; echo "${visited[*]}")
    compopt -o nospace
  fi

  case "${__argwork_lookup_types[$key]}" in
    from)
      if [[ -f "${ARGWORK_CLI_DIR}/.opts/${__argwork_lookup_values[$key]}" ]]
      then
        IFS=$'\n' COMPREPLY=($(compgen -W "$(cat "${ARGWORK_CLI_DIR}/.opts/${__argwork_lookup_values[$key]}" | grep -vwE "$visited_pattern")" "${prefix[@]}" -- $comp_word))
      fi
      ;;

    opts)
      local split_into_lines="$(echo "${__argwork_lookup_values[$key]}" | sed 's/,/\n/g')"
      IFS=$'\n' local opts_split=($(echo "$split_into_lines"))

      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "${opts_split[@]}" | grep -vwE "$visited_pattern")" "${prefix[@]}" -- "$comp_word"))
      ;;

    shell)
      local shell_code="${__argwork_lookup_values[$key]}"
      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "$(eval "$shell_code")" | grep -vwE "$visited_pattern")" "${prefix[@]}" -- "$comp_word"))
      ;;

    cmd)
      local command_name="${__argwork_lookup_values[$key]}"
      local command_path
      if [[ -x "$ARGWORK_CLI_DIR/.bin/$command_name" ]]
      then
        command_path="$ARGWORK_CLI_DIR/.bin/$command_name"
      else
        command_path="$command_name"
      fi
      local command_line
      local command_args_var="__argwork_command_args__$key"
      declare -a args_var=()
      local command_args_var_len="__argwork_command_args__${key}_len"
      local len="${!command_args_var_len}"

      for at_index in $(seq 0 $(( $len - 1 )))
      do
        args_var[$at_index]="$(eval "echo \"\${$command_args_var[$at_index]}\"")"
      done

      IFS= command_line="$command_path ${args_var[@]}"
      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "$(eval "$command_line")" | grep -vwE "$visited_pattern")" "${prefix[@]}" -- "$comp_word"))
      ;;

    dir)
      COMPREPLY=( $(compgen -d -- "${COMP_WORDS[$word_index]}") )
      ;;

    file)
      COMPREPLY=( $(compgen -f -- "${COMP_WORDS[$word_index]}") )
      ;;

    _)
      IFS=$'\n' COMPREPLY=($(compgen -W '_' -- "${COMP_WORDS[$word_index]}"))
      ;;

    *)
      ;;
  esac
}

__argwork_complete_inspect() {
  declare -A arg_map
  local sector=POSITIONAL
  local option_name=

  for index in $(seq 2 "$((${#COMP_WORDS[@]} - 2))")
  do
    local word="${COMP_WORDS[$index]}"
    local word_1="${COMP_WORDS[$(($index + 1))]}"

    if [[ "$word" == ':' ]]
    then
      continue
    elif [[ "$word" != ':' && "$word_1" == ':' ]]
    then
      sector=OPTIONAL
      if [[ ! -z "$option_name" ]]; then
        return
      fi
      option_name="$word"
    else
      case $sector in
        OPTIONAL)
          if [[ -z "$option_name" ]]; then
            return
          fi
          case "$word" in
            _)
              arg_map["$option_name"]=
              ;;
            *)
              arg_map["$option_name"]="$word"
              ;;
          esac
          option_name=
          ;;
        POSITIONAL)
          arg_map["$(($index - 1))"]="$word"
          ;;
      esac
    fi
  done

  >&2 printf "\n$(tput setaf 240)inspect$(tput sgr0):"

  for key in $(seq 1 $__argwork_positional_param_count)
  do
    local field="$(tput setaf 3)${key}$(tput setaf 238):$(tput sgr0)${__argwork_positional_arg_vars[$key]}"
    >&2 printf "\n  %s%*s $(tput setaf 238)=$(tput sgr0) %s" "$field" "$((19 - ${#key} - ${#__argwork_positional_arg_vars[$key]}))" '' "${arg_map[$key]}"
  done
  for option_name in "${!__argwork_optional_arg_vars[@]}"
  do
    >&2 printf "\n  %s%*s $(tput setaf 238)=$(tput sgr0) %s" "$(tput setaf 13)_$(tput setaf 238):$(tput setaf 5)$option_name$(tput sgr0)" "$((18 - ${#option_name}))" '' "${arg_map[$option_name]}"
  done
  COMPREPLY=('')
}

_argwork_completion() {
  declare -A __argwork_lookup_types
  declare -A __argwork_lookup_values
  declare -a __argwork_positional_arg_vars
  declare -A __argwork_optional_arg_vars

  declare -i __argwork_counter=0
  declare -i __argwork_positional_param_count=0
  declare -i __argwork_optional_param_count=0

  __argwork_positional_arg_vars[0]=

  local argwork_script_path="$(__argwork_script_name_to_path "${COMP_WORDS[1]}")"
  local argwork_abs_script_path="$ARGWORK_CLI_DIR/${argwork_script_path} .sh"

  if [ "$COMP_CWORD" -gt 1 ] && [ ! -f "$argwork_abs_script_path" ]
  then
    COMPREPLY=('' '')
    return
  fi

  local argwork_global_env_path="$ARGWORK_CLI_DIR/.env.sh"
  [[ -f "$argwork_global_env_path" ]] && . "$argwork_global_env_path"

  if [[ "${COMP_WORDS[$COMP_CWORD]}" == '?' && $COMP_TYPE == 63 ]]
  then
    ARGWORK_COMPLETION_MODE=HELP
    declare -i __argwork_help_indent=0
    >&2 echo
    >&2 echo "$(tput setaf 240)usage$(tput sgr0):"
    # Include the actual runnable script
    . "$argwork_abs_script_path"

    COMPREPLY=('')
    >&2 echo
    return

  elif [[ "${COMP_WORDS[$COMP_CWORD]}" == '??' && $COMP_TYPE == 63 ]]
  then
    ARGWORK_COMPLETION_MODE=INSPECT
    # Include the actual runnable script
    . "$argwork_abs_script_path"

    __argwork_complete_inspect
    return

  elif [ "${COMP_CWORD}" -eq 1 ]
  then
    # The first section is completed with script names located at the ARGWORK_CLI_DIR
    local IFS=$'\n'
    local word="${COMP_WORDS[1]}"
    local script_sub_rel="${word%/*}"
    [[ "$word" != *'/'* ]] && script_sub_rel=
    local script_sub_name="${word##*/}"
    local script_sub_rel_dir="$(__argwork_script_name_to_path "$script_sub_rel")"
    local script_sub_abs_dir="$script_sub_rel_dir"
    local script_dir="$ARGWORK_CLI_DIR/$script_sub_abs_dir"

    COMPREPLY=($(compgen -W "$(find "$script_dir" -mindepth 1 -maxdepth 1 -not -name '.*' -type f -name "${script_sub_name}* .sh" -printf "${script_sub_rel:+$script_sub_rel/}%f\n" -o -not -name '.*' -type d -name "${script_sub_name}*" -printf "${script_sub_rel:+$script_sub_rel/}%f/\n" | sed 's/ .sh$//g'| sort)" -- "$word")) && compopt -o filenames
    [[ $COMPREPLY == */ ]] && compopt -o nospace
    return

  elif [ "${COMP_CWORD}" -gt 1 ]
  then
    ARGWORK_COMPLETION_MODE=COMPLETE
    # Source the target argwork
    . "$argwork_abs_script_path"
    # eval "$(sed '/^main() {/Q')" "$argwork_abs_script_path"

    __argwork_complete
    return
  fi
}

at() {
  __argwork_counter+=1
  case "$ARGWORK_COMPLETION_MODE" in
    HELP)     __argwork_one_help "$@" ;;
    INSPECT)  __argwork_one "$@" ;;
    COMPLETE) __argwork_one "$@" ;;
  esac
}
