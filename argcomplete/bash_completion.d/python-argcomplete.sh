# Copyright 2012-2013, Andrey Kislyuk and argcomplete contributors.
# Licensed under the Apache License. See https://github.com/kislyuk/argcomplete for more info.

# Copy of __expand_tilde_by_ref from bash-completion
__python_argcomplete_expand_tilde_by_ref () {
    if [ "${!1:0:1}" = "~" ]; then
        if [ "${!1}" != "${!1//\/}" ]; then
            eval $1="${!1/%\/*}"/'${!1#*/}';
        else
            eval $1="${!1}";
        fi;
    fi
}

# Returns the suggested completion list
__python_argcomplete_get_compreply() {
    local executable="python"
    local pyFile="${COMP_WORDS[$((_ARGCOMPLETE-1))]}"
    if [[ _ARGCOMPLETE -gt 1 ]]; then
        # first word is the python executable
        executable="${COMP_WORDS[0]}"
    else
        # first word is a python file
        # use the shebang as executable
        local shebang=$(head -n 1 "$pyFile")
        if [[ "$shebang" == '#!'* ]]; then
            executable=$(echo "$shebang" | tr -d '\r#!')
        fi
    fi
    # get completions
    eval "$executable" -m argcomplete._suppressStdOutErr "$pyFile"
}

_python_argcomplete_global() {
    local executable=$1
    __python_argcomplete_expand_tilde_by_ref executable

    local ARGCOMPLETE=0
    if [[ "$executable" == python* ]] || [[ "$executable" == pypy* ]]; then
        if [[ "${COMP_WORDS[1]}" == -m ]]; then
            if "$executable" -m argcomplete._check_module "${COMP_WORDS[2]}" >/dev/null 2>&1; then
                ARGCOMPLETE=3
            else
                return
            fi
        elif [[ -f "${COMP_WORDS[1]}" ]] && (head -c 1024 "${COMP_WORDS[1]}" | grep --quiet "PYTHON_ARGCOMPLETE_OK") >/dev/null 2>&1; then
            local ARGCOMPLETE=2
        else
            return
        fi
    elif which "$executable" >/dev/null 2>&1; then
        local SCRIPT_NAME=$(which "$executable")
        if (type -t pyenv && [[ "$SCRIPT_NAME" = $(pyenv root)/shims/* ]]) >/dev/null 2>&1; then
            local SCRIPT_NAME=$(pyenv which "$executable")
        fi
        if (head -c 1024 "$SCRIPT_NAME" | grep --quiet "PYTHON_ARGCOMPLETE_OK") >/dev/null 2>&1; then
            local ARGCOMPLETE=1
        elif (head -c 1024 "$SCRIPT_NAME" | egrep --quiet "(PBR Generated)|(EASY-INSTALL-(SCRIPT|ENTRY-SCRIPT|DEV-SCRIPT))" \
            && [[ "$(head -n 1 "$SCRIPT_NAME")" =~ ^#!(.*)$ ]] && [[ "${BASH_REMATCH[1]}" =~ ^.*(python|pypy)[0-9\.]*$ ]] \
            && "$BASH_REMATCH" "$(which python-argcomplete-check-easy-install-script)" "$SCRIPT_NAME") >/dev/null 2>&1; then
            local ARGCOMPLETE=1
        fi
    fi

    if [[ $ARGCOMPLETE != 0 ]]; then
        local IFS=$(echo -e '\v')
        COMPREPLY=( $(_ARGCOMPLETE_IFS="$IFS" \
            COMP_LINE="$COMP_LINE" \
            COMP_POINT="$COMP_POINT" \
            COMP_TYPE="$COMP_TYPE" \
            _ARGCOMPLETE_COMP_WORDBREAKS="$COMP_WORDBREAKS" \
            _ARGCOMPLETE=$ARGCOMPLETE \
            _ARGCOMPLETE_SUPPRESS_SPACE=1 \
            __python_argcomplete_get_compreply) )
        if [[ $? != 0 ]]; then
            unset COMPREPLY
        elif [[ "$COMPREPLY" =~ [=/:]$ ]]; then
            compopt -o nospace
        fi
    else
        type -t _completion_loader | grep -q 'function' && _completion_loader "$@"
    fi
}
complete -o default -o bashdefault -D -F _python_argcomplete_global
