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

  if [[ "$index" == '_' ]]; then index="$var"; fi

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
          __argwork_lookup_values["$index"]='[/path/do/directory]'
          ;;
        file)
          __argwork_lookup_types["$index"]='file'
          __argwork_lookup_values["$index"]='[/path/do/file]'
          ;;
      esac
      ;;

    test)
      local spec="$1"; shift
      case "$spec" in
        uuid)
          __argwork_lookup_types["$index"]='uuid'
          __argwork_lookup_values["$index"]="[UUID]"
          ;;
        date)
          __argwork_lookup_types["$index"]='date'
          __argwork_lookup_values["$index"]='[YYYY-MM-DD]'
          ;;
        text)
          __argwork_lookup_types["$index"]='text'
          __argwork_lookup_values["$index"]='[TEXT]'
          ;;
        regex)
          __argwork_lookup_types["$index"]='regex'
          __argwork_lookup_values["$index"]='[REGEX]'
          ;;
        integer)
          __argwork_lookup_types["$index"]='integer'
          __argwork_lookup_values["$index"]='[INTEGER]'
          ;;
        decimal)
          __argwork_lookup_types["$index"]='decimal'
          __argwork_lookup_values["$index"]='[DECIMAL]'
          ;;
        float)
          __argwork_lookup_types["$index"]='float'
          __argwork_lookup_values["$index"]='[FLOAT]'
          ;;
      esac
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

  local key=
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

  case "${__argwork_lookup_types[$key]}" in
    from)
      if [[ -f "${ARGWORK_CLI_DIR}/.opts/${__argwork_lookup_values[$key]}" ]]; then
        IFS=$'\n' COMPREPLY=($(compgen -W "$(cat "${ARGWORK_CLI_DIR}/.opts/${__argwork_lookup_values[$key]}")" -- "${COMP_WORDS[$word_index]}"))
      fi
      ;;

    opts)
      split_into_lines="$(echo "${__argwork_lookup_values[$key]}" | sed 's/,/\n/g')"
      IFS=$'\n' opts_split=($(echo "$split_into_lines"))

      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "${opts_split[@]}")" -- "${COMP_WORDS[$word_index]}"))
      ;;

    shell)
      shell_code="${__argwork_lookup_values[$key]}"
      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "$(eval "$shell_code")")" -- "${COMP_WORDS[$word_index]}"))
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
      IFS= command_line="$command_path ${__argwork_command_args[@]}"
      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "$(eval "$command_line")")" -- "${COMP_WORDS[$word_index]}"))
      ;;

    uuid | date | text | integer | decimal | float)
      IFS=$'\n' COMPREPLY=($(compgen -W "${__argwork_lookup_values[$key]}" -- "${COMP_WORDS[$word_index]}"))
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
  local help_spec=''

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
  local help_spec=''

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
    # The first section is completed with script names at the ARGWORK_CLI_DIR
    # Start the script file name with a prefix '_ ' to make it available
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
      # Include the actual runnable script
      . "$argwork_abs_script_path"

      __argwork_complete
    return
  fi
}

# Wire up a custom command autocompletion in .bashrc:
# complete -o nosort -F _argwork_completion <command


# High level interface
at() {
  __argwork_one "$@"
}
