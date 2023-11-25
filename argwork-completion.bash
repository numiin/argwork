#!/bin/bash

__argwork_one() {
  local index="$1"
  local var="$2"
  local type="$3"

  if [[ "$index" != '_' && "$var" != '_' ]]; then
    eval "$var='${COMP_WORDS[$(($index + 1))]}'"
  fi

  # update index
  case "$index" in
    _)
      if [[ ! -v __ARGWORK_OPTIONAL_ARG_VARS[$var] ]]
      then
        __ARGWORK_OPTIONAL_PARAM_COUNT=$(($__ARGWORK_OPTIONAL_PARAM_COUNT + 1))
        __ARGWORK_OPTIONAL_ARG_VARS["$var"]="$var"
      fi
      ;;
    *)
      if (($__ARGWORK_POSITIONAL_PARAM_COUNT < $index))
      then
        __ARGWORK_POSITIONAL_PARAM_COUNT=$index
      fi
      __ARGWORK_POSITIONAL_ARG_VARS[$index]="$var"
      ;;
  esac

  if [[ "$index" == '_' ]]; then index="$var"; fi

  case "$type" in
    from)
      __ARGWORK_LOOKUP_TYPES["$index"]='from'
      __ARGWORK_LOOKUP_VALUES["$index"]="$4"
      ;;
    opts)
      local arg_list=(${@:4})
      __ARGWORK_LOOKUP_TYPES["$index"]='opts'
      __ARGWORK_LOOKUP_VALUES["$index"]=$(IFS=, ; echo "${arg_list[*]}")
      ;;
    shell)
      __ARGWORK_LOOKUP_TYPES["$index"]='shell'
      __ARGWORK_LOOKUP_VALUES["$index"]="$4"
      ;;
    command|cmd)
      __ARGWORK_LOOKUP_TYPES["$index"]='command'
      __ARGWORK_LOOKUP_VALUES["$index"]="$4"
      __argwork_command_args=(${@:5})
      ;;
    uuid)
      __ARGWORK_LOOKUP_TYPES["$index"]='uuid'
      __ARGWORK_LOOKUP_VALUES["$index"]="[UUID]"
      ;;
    date)
      __ARGWORK_LOOKUP_TYPES["$index"]='date'
      __ARGWORK_LOOKUP_VALUES["$index"]='[YYYY-MM-DD]'
      ;;
    text)
      __ARGWORK_LOOKUP_TYPES["$index"]='text'
      __ARGWORK_LOOKUP_VALUES["$index"]='[TEXT]'
      ;;
    regex)
      __ARGWORK_LOOKUP_TYPES["$index"]='regex'
      __ARGWORK_LOOKUP_VALUES["$index"]='[REGEX]'
      ;;
    integer)
      __ARGWORK_LOOKUP_TYPES["$index"]='integer'
      __ARGWORK_LOOKUP_VALUES["$index"]='[INTEGER]'
      ;;
    dir)
      __ARGWORK_LOOKUP_TYPES["$index"]='dir'
      __ARGWORK_LOOKUP_VALUES["$index"]='[/path/do/directory]'
      ;;
    file)
      __ARGWORK_LOOKUP_TYPES["$index"]='file'
      __ARGWORK_LOOKUP_VALUES["$index"]='[/path/do/file]'
      ;;
    _)
      __ARGWORK_LOOKUP_TYPES["$index"]='_'
      __ARGWORK_LOOKUP_VALUES["$index"]=
      ;;
    ...)
      __ARGWORK_LOOKUP_TYPES["$index"]=
      __ARGWORK_LOOKUP_VALUES["$index"]=
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
  if [[ ${COMP_CWORD} -gt $(($__ARGWORK_POSITIONAL_PARAM_COUNT + $__ARGWORK_OPTIONAL_PARAM_COUNT * 3 + 1)) ]]; then return; fi

  local sector=POSITIONAL
  if (( $__ARGWORK_POSITIONAL_PARAM_COUNT > 0 && ${COMP_CWORD} > $__ARGWORK_POSITIONAL_PARAM_COUNT + 1))
  then
    sector=OPTIONAL
  fi

  local key=
  local key_shift=0
  case $sector in
    POSITIONAL)
      key="$(($COMP_CWORD - 1))"
      ;;
    OPTIONAL)
      if [[ "${COMP_WORDS[$COMP_CWORD]}" == ':' ]]
      then
        key="${COMP_WORDS[$(($COMP_CWORD - 1))]}"
        key_shift=1
        if [[ -z "$key" || ! -v __ARGWORK_OPTIONAL_ARG_VARS[$key] ]]; then return; fi
      elif [[ "${COMP_WORDS[$(($COMP_CWORD - 1))]}" == ':' ]]
      then
        key="${COMP_WORDS[$(($COMP_CWORD - 2))]}"
        key_shift=0
        if [[ -z "$key" || ! -v __ARGWORK_OPTIONAL_ARG_VARS[$key] ]]; then return; fi
      else
        COMPREPLY=($(compgen -W "$(printf "%s\n" "${__ARGWORK_OPTIONAL_ARG_VARS[@]/%/:}")" -- "${COMP_WORDS[$COMP_CWORD]}"))
        return
      fi
      ;;
  esac

  local word_index=$(($COMP_CWORD + $key_shift))

  # echo "==> DEBUG: __ARGWORK_POSITIONAL_PARAM_COUNT=$__ARGWORK_POSITIONAL_PARAM_COUNT ; __ARGWORK_OPTIONAL_PARAM_COUNT=$__ARGWORK_OPTIONAL_PARAM_COUNT ; __ARGWORK_LOOKUP_TYPES=$!__ARGWORK_LOOKUP_TYPES[@]} ; key=$key ; __ARGWORK_LOOKUP_TYPES[key]=${__ARGWORK_LOOKUP_TYPES[$key]} ; __ARGWORK_POSITIONAL_ARG_VARS=[${__ARGWORK_POSITIONAL_ARG_VARS[@]}]" >> ~/argwork-completion.bash.log

  case "${__ARGWORK_LOOKUP_TYPES[$key]}" in
    from)

      if [[ -f "${ARGWORK_CLI_DIR}/.opts/${__ARGWORK_LOOKUP_VALUES[$key]}" ]]; then
        IFS=$'\n' COMPREPLY=($(compgen -W "$(cat "${ARGWORK_CLI_DIR}/.opts/${__ARGWORK_LOOKUP_VALUES[$key]}")" -- "${COMP_WORDS[$word_index]}"))
      fi
      ;;
    opts)

      split_into_lines="$(echo "${__ARGWORK_LOOKUP_VALUES[$key]}" | sed 's/,/\n/g')"
      IFS=$'\n' opts_split=($(echo "$split_into_lines"))

      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "${opts_split[@]}")" -- "${COMP_WORDS[$word_index]}"))
      ;;

    shell)
      shell_code="${__ARGWORK_LOOKUP_VALUES[$key]}"
      IFS=$'\n' COMPREPLY=($(compgen -W "$(printf "%s\n" "$(eval "$shell_code")")" -- "${COMP_WORDS[$word_index]}"))
      ;;

    command)
      local command_name="${__ARGWORK_LOOKUP_VALUES[$key]}"
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

    uuid | date | text | integer)
      IFS=$'\n' COMPREPLY=($(compgen -W "${__ARGWORK_LOOKUP_VALUES[$key]}" -- "${COMP_WORDS[$word_index]}"))
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

  for key in $(seq 1 $__ARGWORK_POSITIONAL_PARAM_COUNT)
  do
    local spec=
    local var_name="${__ARGWORK_POSITIONAL_ARG_VARS[$key]}"
    if [[ "$var_name" == '_' ]]; then
      spec='...'
    else
      spec="$key:$var_name"
    fi
    help_spec="$help_spec  [$spec]"
  done
  local optional_arg_spec="${__ARGWORK_OPTIONAL_ARG_VARS[@]}"
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

  for key in $(seq 1 $__ARGWORK_POSITIONAL_PARAM_COUNT)
  do
    local field="${key}:${__ARGWORK_POSITIONAL_ARG_VARS[$key]}"
    printf '\n  %s%*s = %s' "$field" "$((20-${#field}))" '' "${arg_map[$key]}"
  done
  for option_name in "${!__ARGWORK_OPTIONAL_ARG_VARS[@]}"
  do
    printf '\n  %s%*s = %s' "_:$option_name" "$((18-${#option_name}))" '' "${arg_map[$option_name]}"
  done
  COMPREPLY=('')
}

_argwork_completion() {
  declare -A __ARGWORK_LOOKUP_TYPES
  declare -A __ARGWORK_LOOKUP_VALUES
  declare -a __ARGWORK_POSITIONAL_ARG_VARS
  declare -A __ARGWORK_OPTIONAL_ARG_VARS
  declare -a __ARGWORK_CURRENT_VALS

  __ARGWORK_POSITIONAL_PARAM_COUNT=0
  __ARGWORK_OPTIONAL_PARAM_COUNT=0
  __ARGWORK_POSITIONAL_ARG_VARS[0]=
  __ARGWORK_CURRENT_VALS[0]=

  local argwork_script_path="$(__argwork_script_name_to_path "${COMP_WORDS[1]}")"
  local argwork_abs_script_path="$ARGWORK_CLI_DIR/${argwork_script_path} .sh"

  if [ "$COMP_CWORD" -gt 1 ] && [ ! -f "$argwork_abs_script_path" ]
  then
    COMPREPLY=('' '')
    return
  fi

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
    local script_dir="${ARGWORK_CLI_DIR}/${script_sub_abs_dir}"

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
