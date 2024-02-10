#!/bin/bash

__argwork_one() {
  local index="$1"
  local var="$2"
  local type="$3"

  if [[ "$index" != '_' && "$index" != '-' && "$var" != '_' ]]; then
    eval "$var='${COMP_WORDS[$(($index + 1))]}'"
  fi

  # update index
  case "$index" in
    -)
      ;;
    _)
      if [[ ! -v __argwork_optional_arg_vars[$var] ]]
      then
        __argwork_optional_param_count=$(($__argwork_optional_param_count + 1))
        __argwork_optional_arg_vars["$var"]="$var"
      fi
      ;;
    *)
      if (($__argwork_positional_param_count < $index))
      then
        __argwork_positional_param_count=$index
      fi
      __argwork_positional_arg_vars[$index]="$var"
      ;;
  esac

  [[ "$index" == '_' ]] && index="$var"

  shift 3

  case "$type" in
    opts)
      local spec="$1"; shift
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
          __argwork_lookup_types["$index"]='command'
          __argwork_lookup_values["$index"]="$1"
          __argwork_command_args=(${@:2})
          ;;
        dir)
          __argwork_lookup_types["$index"]='dir'
          __argwork_lookup_values["$index"]='[/path/to/directory]'
          ;;
        file)
          __argwork_lookup_types["$index"]='file'
          __argwork_lookup_values["$index"]='[/path/to/file]'
          ;;
      esac
      ;;

    spec)
      local spec list_mark hint
      case "$1" in
        list)
          list_mark=s
          shift
          spec="$1"
          ;;
        *)
          spec="$1"
          ;;
      esac
      shift
      case "$spec" in
        uuid)    hint='UUID' ;;
        date)    hint='YYYY-MM-DD' ;;
        text)    hint='TEXT' ;;
        regex)   hint='REGEX' ;;
        integer) hint='INTEGER' ;;
        decimal) hint='DECIMAL' ;;
        float)   hint='FLOAT' ;;
      esac
      __argwork_lookup_types["$index"]="$spec$list_mark"
      __argwork_lookup_values["$index"]="[$hint]$list_mark"
      ;;

    _)
      __argwork_lookup_types["$index"]='_'
      __argwork_lookup_values["$index"]=
      ;;

    ...)
      __argwork_lookup_types["$index"]=
      __argwork_lookup_values["$index"]=
      ;;

    *)
      ;;
  esac
}

__argwork_expand_env_vars() {
  local result="$1"
  local match="$(echo "$1" | grep -o '[#]\w\+')"
  local var_name
  while [ ! -z "$match" ]
  do
    var_name="${match:1}"
    [[ -z "${!var_name}" ]] && >&2 __argwork_error "Expanded variable [$var_name] has no value"
    result="$(echo "$result" | sed "s/$match/${!var_name}/")"
    match="$(echo "$result" | grep -o '[#]\w\+')"
  done
  echo "$result"
}


__argwork_script_name_to_path() {
  echo "$1"
}

__argwork_complete() {
  # Optionals consist of three parts and are specifired like <param>:<value>
  if [[ $COMP_CWORD -gt $(($__argwork_positional_param_count + $__argwork_optional_param_count * 3 + 1)) ]]; then return; fi

  local sector=POSITIONAL
  if (( $__argwork_positional_param_count > 0 && $COMP_CWORD > $__argwork_positional_param_count + 1))
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

  # echo "==> DEBUG: __argwork_positional_param_count=$__argwork_positional_param_count ; __argwork_optional_param_count=$__argwork_optional_param_count ; __argwork_lookup_types=$!__argwork_lookup_types[@]} ; key=$key ; __argwork_lookup_types[key]=${__argwork_lookup_types[$key]} ; __argwork_positional_arg_vars=[${__argwork_positional_arg_vars[@]}]" >> ~/argwork-completion.bash.log

  local prefix=()
  local visited_pattern
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

    command)
      local command_name="${__argwork_lookup_values[$key]}"
      local command_path
      if [[ -x "$ARGWORK_CLI_DIR/.bin/$command_name" ]]
      then
        command_path="$ARGWORK_CLI_DIR/.bin/$command_name"
      else
        command_path="$command_name"
      fi
      local command_line

      # perform environment variable substitutions marked by #
      for at_index in $(seq 0 $(( ${#__argwork_command_args[@]} - 1 )))
      do
        __argwork_command_args[$at_index]="$(__argwork_expand_env_vars "${__argwork_command_args[$at_index]}")"
      done

      IFS= command_line="$command_path ${__argwork_command_args[@]}"
      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "$(eval "$command_line")" | grep -vwE "$visited_pattern")" "${prefix[@]}" -- "$comp_word"))
      ;;

    uuid | date | text | integer | decimal | floats | uuids | dates | texts | integers | decimals | floats)
      IFS=$'\n' COMPREPLY=($(compgen -W "${__argwork_lookup_values[$key]}" "${prefix[@]}" -- "$comp_word"))
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

__argwork_complete_help() {
  local help_spec

  for key in $(seq 1 $__argwork_positional_param_count)
  do
    local spec=
    local var_name="${__argwork_positional_arg_vars[$key]}"
    if [[ "$var_name" == '_' ]]; then
      spec='...'
    else
      spec="$key:$var_name"
    fi
    help_spec="$help_spec  [$spec]"
  done
  local optional_arg_spec="${__argwork_optional_arg_vars[@]}"
  help_spec="$help_spec  ${optional_arg_spec:+($optional_arg_spec)}"
  COMPREPLY=("usage:$help_spec" '')
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

  printf '\nusage (current):'

  for key in $(seq 1 $__argwork_positional_param_count)
  do
    local field="${key}:${__argwork_positional_arg_vars[$key]}"
    printf '\n  %s%*s = %s' "$field" "$((20-${#field}))" '' "${arg_map[$key]}"
  done
  for option_name in "${!__argwork_optional_arg_vars[@]}"
  do
    printf '\n  %s%*s = %s' "_:$option_name" "$((18-${#option_name}))" '' "${arg_map[$option_name]}"
  done
  COMPREPLY=('')
}

_argwork_completion() {
  declare -A __argwork_lookup_types
  declare -A __argwork_lookup_values
  declare -a __argwork_positional_arg_vars
  declare -A __argwork_optional_arg_vars

  __argwork_positional_param_count=0
  __argwork_optional_param_count=0
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

  if [[ "${COMP_WORDS[$COMP_CWORD]}" == '?' ]]
  then
    # Include the actual runnable script
    . "$argwork_abs_script_path"

    __argwork_complete_help
    return

  elif [[ "${COMP_WORDS[$COMP_CWORD]}" == '??' && $COMP_TYPE == 63 ]]
  then
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
      # Source the target argwork
      . "$argwork_abs_script_path"
      # eval "$(sed '/^main() {/Q')" "$argwork_abs_script_path"

      __argwork_complete
    return
  fi
}

at() {
  __argwork_one "$@"
}
