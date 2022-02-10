# -*- eval: (read-only-mode 1) -*-
# Contains relocation-related functions that are intended to be sourced into
# the current shell.
#
# By default we define some short aliases for our most common functionality.
# To have us define long ones instead (so that you can define your own short
# aliases for them, for example) then include something like
#
#   RELOCATE_DEFINE_SHORT_ALIASES=n
#
# before you source this file. By default the short or long aliases that we
# define can update some environment variables specific to this package: e.g.
# the 'r', 'r1' and 'rp' environment variables. To prevent those aliases from
# doing that include something like
#
#   RELOCATE_MODIFY_ENVIRONMENT=n
#
# before you source this file.
#
# So there are two main ways to use this file:
#
# 1. The Easy Way.
#   a. Source this file - directly or indirectly - from ~/.bashrc;
#   b. add a call to our relocate-update-completions() function in
#      .bash_profile, at least if you want the relocation commands to
#      support autocompletion of relocation aliases; and then
#   c. re-source ~/.bash_profile in each terminal.
#
# 2. The Hard Way.
#   a. Set RELOCATE_DEFINE_SHORT_ALIASES to 'n' and then source this file -
#      directly or indirectly - from ~/.bashrc;
#   b. in ~/.bashrc - or whatever file you define aliases in - define one or
#      more custom aliases, functions, etc. that - possibly among other
#      things - calls one of the _relocate_user_...() functions defined in
#      this file;
#   c. add a call to our relocate-update-completions() function in
#      ~/.bash_profile, giving it as arguments the names of all of the custom
#      aliases, functions, etc. that you defined in step (b.) that you want
#      to support the autocompletion of relocation aliases; and then
#   d. re-source ~/.bash_profile in each terminal.
#
# Copyright (C) 2013-2022 by James MacKay
#
#-This program is free software: you can redistribute it and/or modify
#-it under the terms of the GNU General Public License as published by
#-the Free Software Foundation, either version 3 of the License, or
#-(at your option) any later version.
#
#-This program is distributed in the hope that it will be useful,
#-but WITHOUT ANY WARRANTY; without even the implied warranty of
#-MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#-GNU General Public License for more details.
#
#-You should have received a copy of the GNU General Public License
#-along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#set -x

##
## Configuration.
##

_RELOCATIONS="$HOME/.relocations"


##
## Internal global variables.
##

# The names of all of the commands to update the list of completions for when
# a new relocation alias is defined.
_relocate_all_completion_commands=""

# The return code that indicates that a function was misused (for example
# by passing it the wrong number - or invalid - arguments).
#
# Note: this will be assumed to be a positive integer by code throughout
# this file.
_relocate_misused_return_code=1


##
## Utility functions.
##

## Returns the return code that is its single argument unless that argument
## is the _relocate_misused_return_code, in which case it returns a
## different - but nonzero - return code.
#
# usage: _relocate_not_misused_return_code return-code
function _relocate_not_misused_return_code() {
    local rc=0
    if [ $# -ne 1 ]
    then
        _relocate_report_error "Must be exactly one argument."
        rc=$((_relocate_misused_return_code+1))
    else
        rc=$1
        if [ $rc -eq ${_relocate_misused_return_code} ]
        then
            rc=$((_relocate_misused_return_code+1))
        fi
    fi
    return $rc
}

## Reports that an error occurred in a relocate function.
#
# usage: _relocate_report_error msg ...
function _relocate_report_error() {
    echo "" >&2
    echo "$*" | fold -s -w 65 >&2
    #echo "" >&2
}

## Reports that a function has been misused, returning the appropriate
## return code.
#
# usage: _relocate_report_misused_error msg ...
function _relocate_report_misused_error() {
    _relocate_report_error $*
    return ${_relocate_misused_return_code}
}


## Returns 0 if the specified option is a help option, and 1 if it isn't (and
## 2 if more or fewer than one argument is specified).
#
# usage: _relocate_is_help_option opt
function _relocate_is_help_option() {
    local rc=1
    if [ $# -eq 1 ]
    then
        #echo "arg=$1"
        case "$1" in
            -\?|-h|--help)
                rc=0
                ;;
            *)
                rc=1
                ;;
        esac
    elif [ $# -gt 1 ]
    then
        _relocate_report_error "Too many arguments."
        rc=2
    else  # $# -eq 0
        _relocate_report_error "There is no option to check."
        rc=2
    fi
    return $rc
}


## Returns 0 if 'word' appears as a word in 'str...', and 1 if it doesn't
## (and 2 if 'word' is omitted).
#
# Note: if 'str...' is omitted then the empty string is searched for the
# word instead.
#
# See also: _relocate_ensure_contains_word().
#
# usage: _relocate_contains_word word [str...]
function _relocate_contains_word() {
    local word
    local rc

    if [ $# -eq 0 ]
    then
        _relocate_report_error "No word was specified."
        rc=2
    else
        word="$1"
        shift
        grep -Fwq "$word" << +++EOF+++
$*
+++EOF+++
        rc=$?
    fi

    return $rc
}

## Outputs to standard output 'str...' if it already contains 'word' as a
## word, and 'str... word' if it doesn't. Returns 0 unless 'word' is omitted.
#
# Note: if 'str...' is omitted then the empty string is used in its place,
#
# See also: _relocate_contains_word().
#
# usage: _relocate_ensure_contains_word word [str...]
function _relocate_ensure_contains_word() {
    local word
    local rc=0

    if [ $# -eq 0 ]
    then
        _relocate_report_error "No word was specified."
        rc=1
    else
        word="$1"
        shift
        if _relocate_contains_word "$word" "$@"
        then
            cat << +++EOF+++
$*
+++EOF+++
        elif [ -z "$*" ]
        then
            echo "$word"
        else
            cat << +++EOF+++
$* $word
+++EOF+++
        fi
    fi

    return $rc
}


##
## Modification functions.
##

## Adds 'cmd' to our list of the names of all of the commands to update the
## list of completions for when a new relocation alias is defined (a.k.a.
## _relocate_all_completion_commands).
#
# Note: this function is intended to be accessible to end users (so that they
# can add their own commands (which are usually implemented using one of our
# commands)), and so doesn't start with an underscore.
#
# usage: relocate_add_completion_command cmd
function relocate_add_completion_command() {
    if [ $# -eq 0 ]
    then
        _relocate_report_misused_error "No command was specified."
        return
    elif [ $# -gt 1 ]
    then
        _relocate_report_misused_error "Too many arguments."
        return
    else
#echo "old all cmds=[${_relocate_all_completion_commands}]"
        _relocate_all_completion_commands=$(_relocate_ensure_contains_word "$1" "${_relocate_all_completion_commands}")
#echo "new all cmds=[${_relocate_all_completion_commands}]"
        _relocate_update_completions "$1"
    fi
}

## Updates the (bash) completions for the specified commands.
#
# usage: _relocate_update_completions [command ...]
function _relocate_update_completions() {
    if [ $# -gt 0 ]
    then
        local ras=$(PAGER=cat _relocate_print|awk '{print $1}')
        #echo "reloc. aliases = $ras"
        complete -W "${ras}" $*
    fi
}

## Updates the (bash) completions for the all of the commands in
## _relocate_all_completion_commands.
#
# usage: _relocate_update_all_completions
function _relocate_update_all_completions() {
    local rc=0
    if [ $# -gt 0 ]
    then
        _relocate_report_misused_error "Too many arguments."
        return
    else
        _relocate_update_completions ${_relocate_all_completion_commands}
        _relocate_not_misused_return_code $?
        rc=$?
    fi
    return $rc
}

## Defines the relocation alias 'alias' to be an alias for the directory with
## pathname 'dir'. If the alias 'alias' has already been defined then an
## error is reported (and the existing alias isn't changed) unless the '-f'
## option has been specified, in which case 'alias' is redefined (to alias
## 'dir').
#
# usage: _relocate_set [-f] alias dir
function _relocate_set() {
    local force=0
    if [ $# -gt 0 -a "x$1" = "x-f" ]
    then
        force=1
        shift
    fi
    #echo "num args=$# ; force = $force"

    if [ $# -gt 1 ]
    then
        # Validate the relocation alias.
        local alias="$1"
        #echo "alias=$alias"
        if [ -z "$alias" ]
        then
            _relocate_report_misused_error \
                 "The empty string is not a valid relocation alias."
            return
        else
            invalidChars=$(echo "$alias" | tr -d '[:alnum:]')
            if [ -n "$invalidChars" ]
            then
                _relocate_report_misused_error \
                     "There are invalid characters ($invalidChars) in the relocation alias '$alias'".
                return
            fi
        fi

        # Validate and adjust the directory to be aliased.
        local dir="$2"
        #echo "dir=$dir"
        if [ -z "$dir" ]
        then
            _relocate_report_misused_error \
                "An empty string is not a valid directory to alias."
            return
        elif [ "x${dir}" = "x." ]
        then
            dir="$(pwd)"
        fi
        local old
        old=$(_relocate_print -q "$alias")
        #echo "old=$old"
        if [ -n "${old}" -a $force -eq 0 ]
        then
            cat << +++EOF+++ >&2

The relocation alias '$alias' has already been defined: it
relocates to ${old}.

Use the '-f' option to force replacement of the existing alias
(or choose a different alias).

+++EOF+++
            return 2
        fi

        local r="${_RELOCATIONS}"
        if [ -n "${old}" ]
        then
            # Remove the existing alias from the relocations list.
            local tmp="${r}.$$.tmp"
            grep -v "^${alias}[ ]" "$r" > "$tmp" && mv -f "$tmp" "$r"
        fi
        echo "$alias $dir" >> "$r"
        _relocate_update_all_completions
    elif [ $# -eq 1 ]
    then
        _relocate_report_misused_error "The directory to alias wasn't specified."
        return
    else  # no arguments
        _relocate_report_misused_error \
             "Neither the relocation alias nor the directory it was to alias has been specified."
        return
    fi
    return 0
}


##
## Printing functions.
##

## Prints to standard output the name and value of one environment variable
## with the specified name and value, but only if the value is non-empty.
#
# usage: _relocate_print_one_env_var name value
function _relocate_print_one_env_var() {
    local rc=0
    if [ $# -gt 2 ]
    then
        _relocate_report_misused_error "Too many arguments."
        return
    elif [ $# -eq 1 ]
    then
        _relocate_report_misused_error \
            "No environment variable value was specified."
        return
    elif [ $# -eq 0 ]
    then
        _relocate_report_misused_error \
            "No environment variable name or value was specified."
        return
    else
        rc=0
        if [ -n "$2" ]
        then
            printf "%-2s %s\n" "$1" "$2"
        fi
    fi
    return $rc
}

## Prints to standard output the names and values of the environment
## variables that can be set or modified by the relocation functions.
#
# usage: _relocate_print_env
function _relocate_print_env() {
    local rc=0
    if [ $# -gt 0 ]
    then
        _relocate_report_misused_error "Too many arguments."
        return
    else
        _relocate_print_one_env_var "r" "$r"
        _relocate_print_one_env_var "rr" "$rr"
        _relocate_print_one_env_var "rp" "$rp"
        _relocate_print_one_env_var "r1" "$r1"
        _relocate_print_one_env_var "r2" "$r2"
    fi
    return $rc
}

## If 'alias' isn't specified then prints to standard output the name of each
## relocation alias followed by the directory it aliases (one alias-directory
## pair per line, with the alias and the directory separated by a space).
## Otherwise prints to standard output the directory that the relocation
## alias 'alias' aliases: if 'alias' isn't an existing relocation alias then
## an error message is output to standard error unless the '-q' option has
## been specified, in which case nothing is output to either standard output
## or standard error.
#
# usage: _relocate_print [-q] [alias]
function _relocate_print() {
    local quiet=0

    if [ $# -gt 0 ] && [ "x$1" = "x-q" ]
    then
        quiet=1
        shift
    fi

    local rc=0
    if [ $# -gt 1 ]
    then
        _relocate_report_misused_error "Too many arguments."
        return
    elif [ $# -eq 1 ]
    then
        #echo "_RELOCATIONS=${_RELOCATIONS}"
        local d
        d=$(grep "^${1}[ ]" "${_RELOCATIONS}" 2>/dev/null | cut -d' ' -f2-)
        #echo "d=$d"
        if [ -n "$d" ]
        then
            d=$(echo "$d" | head -n 1)
            echo "$d"
        else
            if [ $quiet -eq 0 ]
            then
                _relocate_report_error "There is no relocation alias named '$1'."
                rc=$((_relocate_misused_return_code+1))
            fi
        fi
    else  # no arguments - print all aliases and the dirs they map to
        cat "${_RELOCATIONS}" 2>/dev/null | sort -f -k 1 | "${PAGER:-less}"
    fi
    return $rc
}

## Outputs to standard out the first subdirectory of 'dir' that starts with
## 'prefix', if there is one (ignoring case if necessary, and if the '-i'
## option is specified). Returns 0 if there's exactly one match, 1 if there's
## more than one match, 2 if there are no matches, and 3 if this function has
## been called incorrectly. A message is also output to standard error unless
## 0 is returned.
#
# Note: the "first" match is determined by sorting all of the matches using
# the sort command and taking the match that it puts first.
#
# usage: _relocate_subdir_matching_prefix [-i] prefix dir
function _relocate_subdir_matching_prefix() {
    local allowCaselessMatches=0
    if [ $# -gt 0 -a "x$1" = "x-i" ]
    then
        allowCaselessMatches=1
        shift
    fi

    if [ $# -eq 0 ]
    then
        _relocate_report_misused_error "No prefix or directory was specified."
        return 3
    elif [ $# -eq 1 ]
    then
        _relocate_report_misused_error "No directory was specified."
        return 3
    fi

    # The arguments to the 'find' command used to find subdirectories under a
    # given directory.
    #
    # Note: the '-L' option allows us to find symlinks to subdirectories too.
    local findArgs="-L . -mindepth 1 -maxdepth 1 -type d"

    #set -x
    local prefix="$1"
    local d="$2"
    if [ -z "$d" ]
    then
        d="/"
    fi
    local first=""
    local msg=""

    local matches
    matches=$(cd "$d" && find ${findArgs} -name "${prefix}*"|cut -c3-|sort)
    local OLDIFS=$IFS
    local sd
    IFS=$'\n'
    for sd in $matches
    do
        if [ -z "$first" ]
        then
            first="$sd"
        else
            if [ -z "$msg" ]
            then
                msg="Also: $d $prefix ->"
                msg="$msg $sd"
            else
                msg="$msg, $sd"
            fi
        fi
    done
    IFS=$OLDIFS

    if [ -z "$first" -a ${allowCaselessMatches} -eq 1 ]
    then
        matches=$(cd "$d" && find ${FIND_ARGS} -iname "${prefix}*"|cut -c3-|sort)
        OLDIFS=$IFS
        IFS=$'\n'
        for sd in $matches
        do
            if [ -z "$first" ]
            then
                first="$sd"
            else
                if [ -z "$msg" ]
                then
                    msg="Also (ignoring case): $d $prefix -> $sd"
                else
                    msg="$msg, $sd"
                fi
            fi
        done
        IFS=$OLDIFS
    fi

    # If there's no exact match and the prefix contains dots (.) then try
    # matching the prefix again, this time allowing each dot to match zero or
    # more characters.
    #
    # Note: iff the prefix starts with a dot then the match may occur
    # somewhere other than at the start of the directory name.
    local newPrefix="${prefix//./*}"
    #echo "newPrefix=[$newPrefix]" >&2
    if [ -z "$first" -a "$prefix" != "$newPrefix" ]
    then
        matches=$(cd "$d" && find ${findArgs} -name "${newPrefix}*"|cut -c3-|sort)
        OLDIFS=$IFS
        IFS=$'\n'
        for sd in $matches
        do
            if [ -z "$first" ]
            then
                first="$sd"
            else
                if [ -z "$msg" ]
                then
                    msg="Also (wildcards): $d $prefix -> $sd"
                else
                    msg="$msg, $sd"
                fi
            fi
        done
        IFS=$OLDIFS

        # If there's still no match and we haven't already done so, then try
        # matching the prefix again, this time allowing it to match anywhere
        # in the name (and not just at the start).
        if [ -z "$first" -a "${newPrefix:0:1}" != "*" ]
        then
            matches=$(cd "$d" && find ${findArgs} -name "*${newPrefix}*"|cut -c3-|sort)
            OLDIFS=$IFS
            IFS=$'\n'
            for sd in $matches
            do
                if [ -z "$first" ]
                then
                    first="$sd"
                else
                    if [ -z "$msg" ]
                    then
                        msg="Also (non-prefix wildcards): $d $prefix -> $sd"
                    else
                        msg="$msg, $sd"
                    fi
                fi
            done
            IFS=$OLDIFS
        fi
    fi

    local rc=0
    if [ -z "$first" ]
    then
        cat << +++EOF+++ >&2
There's no subdirectory of $d that starts with '$prefix'.
+++EOF+++
        rc=2
    else
        if [ -n "$msg" ]
        then
            echo "$msg" >&2
            rc=1
        else
            rc=0  # exactly one match
        fi
        echo "$first"
    fi
    return $rc
}

## If 'alias' isn't specified then prints to standard output the name of each
## relocation alias followed by the directory it aliases (one alias-directory
## pair per line, with the alias and the directory separated by a space).
## Otherwise prints to standard output the directory that the relocation
## alias 'alias' combined with any and all 'subdir-prefix' subdirectory
## prefixes correspond to.
#
# usage: _relocate_print_additional [alias [subdir-prefix ...]]
function _relocate_print_additional() {
    #echo "---> in _relocate_print_additional() ..." >&2
    local rc=0
    if [ $# -eq 0 ]
    then
        # Output all alias-directory mappings.
        #echo "No args specified." >&2
        _relocate_print
        rc=$?
    else
        #echo "first arg = [$1]" >&2
        local d
        if [ "x$1" = "x." ]
        then
            # The first argument is the built-in alias for the current
            # working directory.
            d="."
        elif [ "x$1" = "x/" ]
        then
            # The first argument is the built-in alias for the root dir.
            #
            # We set 'd' to an empty string so that if there are subdirs our
            # result doesn't start with "//". The case where no subdirs are
            # specified is handled specially below.
            d=""
        else
            d=$(_relocate_print "$1")
            _relocate_not_misused_return_code $?
            rc=$?
        fi
        shift

        if [ $rc -eq 0 -a $# -gt 0 ]
        then
            for prefix in "$@"
            do
                if [ "x${prefix}" = "x.." ]
                then
                    d="${d}/${prefix}"
                else
                    sd=$(_relocate_subdir_matching_prefix "$prefix" "$d")
                    if [ $? -le 1 ]
                    then
                        d="${d}/${sd}"
                    else
                        rc=$((_relocate_misused_return_code+1))
                        break  # for
                    fi
                fi
            done
        fi

        if [ $rc -eq 0 ]
        then
            if [ -n "$d" ]
            then
                echo "$d"
            else
                # The relocation alias was the ROOT_ALIAS and there were no
                # subdirs.
                echo "/"
            fi
        fi
    fi

    #echo "_relocate_print_additional() return code = $rc" >&2
    return $rc
}

## The same as _relocate_print_additional(), except that iff the alias and
## subdirectory prefixes do correspond to a directory then some environment
## variables are also set or modified.
#
# The following are the environment variables that are set or modified:
#  - 'r2' is set to the value of the environment variable 'r1' iff 'r1' is
#    defined,
#  - 'r1' is set to the value of the environment variable 'rp' iff 'rp' is
#    defined, and
#  - 'rp' is set to the directory that the alias and subdirectory prefixes
#    correspond to
#
# If no arguments are specified then no environment variables are set or
# modified and we output what _relocate_print_additional() would.
#
# See also: _relocate_print_additional().
#
# usage: _relocate_print_additional_set_env [alias [subdir-prefix ...]]
function _relocate_print_additional_set_env() {
    local rc
    if [ $# -eq 0 ]
    then
        _relocate_print_additional
        rc=$?
    else
        local res=$(_relocate_print_additional $*)
        rc=$?
        if [ $rc -eq 0 ]
        then
            echo "$res"
            if [ "x${r1}" != "x" ]
            then
                export r2="$r1"
            fi
            if [ "x${rp}" != "x" ]
            then
                export r1="$rp"
            fi
            export rp="$res"
        fi
    fi
    return $rc
}


##
## Directory changing functions.
##

## If 'alias' is an existing relocation alias then changes the current
## working directory to the directory that 'alias' is an alias for.
#
# usage: _relocate alias
function _relocate() {
    local rc=0
    if [ $# -eq 1 ]
    then
        local res
        res=$(_relocate_print "$1")
        _relocate_not_misused_return_code $?
        rc=$?
        if [ $rc -eq 0 -a -n "$res" ]
        then
            # The redirect prevents output from 'cd -' (and others?).
            cd "$res" > /dev/null && pwd
            _relocate_not_misused_return_code $?
            rc=$?
        fi
    else
        # Output all alias-directory mappings if $# -eq 0, and an error
        # message otherwise.
        _relocate_print $*
        rc=$?
    fi
    return $rc
}

## Changes the current working directory to the directory that the relocation
## alias combined with the 'subdir-prefix' subdirectory prefixes correspond
## to.
#
# usage: _relocate_additional alias [subdir-prefix ...]
function _relocate_additional() {
    local rc=0
    local res
    if [ $# -eq 0 ]
    then
        # Relocate to the previous directory by default.
        res="-"
    else
        res=$(_relocate_print_additional $*)
        rc=$?
    fi
    #echo "in _relocate_additional() ..."
    if [ $rc -eq 0 -a -n "$res" ]
    then
        # The redirect prevents output from 'cd -' (and others?).
        cd "$res" > /dev/null && pwd
        _relocate_not_misused_return_code $?
        rc=$?
    fi
    return $rc
}

## The same as _relocate_additional(), except that iff the alias and
## subdirectory prefixes do correspond to a directory 'd' then some
## environment variables are also potentially set, assuming that we change to
## a different directory.
#
# The following environment variables are potentially set:
#  - 'rr' is set to the current working directory BEFORE we change it to 'd',
#    and
#  - 'r' is set to 'd'
#
# If we "change" to the same directory we were in then no environment
# variables are set or modified.
#
# See also: _relocate_additional().
#
# usage: _relocate_additional_set_env alias [subdir-prefix ...]
function _relocate_additional_set_env() {
    local old
    old="$(pwd)"
    _relocate_additional $*
    local rc=$?
    if [ $rc -eq 0 -a $# -gt 0 ]
    then
        local new
        new="$(pwd)"
        if [ "$old" != "$new" ]
        then
            export rr="$old"
            export r="$new"
        fi
    fi
    return $rc
}


##
## Simple "wrapper" functions.
##

## Prints to standard output all of the relocation alias-directory pairs that
## contain the specified regular expression pattern.
function _relocate_find() {
    if [ $# -gt 1 ]
    then
        _relocate_report_misused_error "Too many arguments."
        return
    elif [ $# -eq 0 ]
    then
        _relocate_report_misused_error \
            "The pattern to search for wasn't specified."
        return
    else
        _relocate_print_additional|grep --colour=never "$1"
        _relocate_not_misused_return_code $?
        return
    fi
}

## Prints to standard output a long listing of the contents of the directory
## whose name is the value of the environment variable "rp".
function _relocate_long_rp_list() {
    local rc=0
    if [ "x${rp}" = "x" ]
    then
        _relocate_report_error "The environment variable 'rp' isn't set."
        rc=$((_relocate_misused_return_code+1))
    else
        (cd "$rp" && ls -l $*)
    fi
    return $rc
}

## Prints to standard output a short listing of the contents of the directory
## whose name is the value of the environment variable "rp".
function _relocate_short_rp_list() {
    local rc=0
    if [ "x${rp}" = "x" ]
    then
        _relocate_report_error "The environment variable 'rp' isn't set."
        rc=$((_relocate_misused_return_code+1))
    else
        (cd "$rp" && ls $*)
    fi
    return $rc
}

## Prints to standard output a long listing of the contents of the directory
## whose name is the value of the environment variable "rr".
#
# Note: there's no version of this function for the environment variable "r"
# because that's almost always the current working directory.
function _relocate_long_rr_list() {
    local rc=0
    if [ "x${rr}" = "x" ]
    then
        _relocate_report_error "The environment variable 'rr' isn't set."
        rc=$((_relocate_misused_return_code+1))
    else
        (cd "$rr" && ls -l $*)
    fi
    return $rc
}

## Prints to standard output a short listing of the contents of the directory
## whose name is the value of the environment variable "rr".
#
# Note: there's no version of this function for the environment variable "r"
# because that's almost always the current working directory.
function _relocate_short_rr_list() {
    local rc=0
    if [ "x${rr}" = "x" ]
    then
        _relocate_report_error "The environment variable 'rr' isn't set."
        rc=$((_relocate_misused_return_code+1))
    else
        (cd "$rr" && ls $*)
    fi
    return $rc
}


##
## Help functions.
##

## Outputs to standard output the help message for the
## _relocate_print_additional() function.
#
# See also: _relocate_print_additional().
#
# usage: _relocate_help_relocate_print_additional name
function _relocate_help_relocate_print_additional() {
    cat << +++EOF+++
usage $1 alias [subdir-prefix ...]

where 'alias' is the relocation alias of the directory to write
to the standard output, unless one or more 'subdir-prefix'es are
specified, in which case we write the following directory to the
standard output:

  - if there is one 'subdir-prefix', the first subdirectory of
    the directory corresponding to the relocation alias 'alias'
    that matches 'subdir-prefix'; otherwise

  - if there are 'n' 'subdir-prefix'es 'prefix-1', ...,
    'prefix-n' (where n > 1), the first subdirectory of the
    directory that 'alias' and the first n-1 'subdir-prefix'es
    would have relocated us to that matches 'prefix-n'.

If one of the 'subdir-prefix'es doesn't match any subdirectories
of the appropriate directory then the pathname of that directory
will be output in an error message.

A prefix is matched against a directory's subdirectories as
follows: if one or more subdirectories start with the prefix
then those are the matches to the prefix; otherwise if caseless
matches are allowed and one or more start with the prefix -
ignoring any differences in case - then those are the matches to
the prefix; otherwise if the prefix contains one or more dots
(.) and one or more subdirectories start with the prefix if we
allow each dot to match any sequence of zero or more characters
then those are the matches to the prefix; otherwise if the prefix
doesn't start with a dot and one or more subdirectories contain
the prefix if we allow each dot to match any sequence of zero or
more characters then those are the matches to the prefix.

Note: if 'alias' is '.' (which is not a valid user-defined alias,
and so cannot conflict with one) then it is treated as being an
alias for the current working directory. And if 'alias' is '/'
(which is also not a valid user-defined alias) then it is treated
as being an alias for the root directory.

+++EOF+++
}


## Outputs to standard output the help message for the
## _relocate_print_additional_set_env() function.
#
# See also: _relocate_print_additional_set_env().
#
# usage: _relocate_help_relocate_print_additional_set_env name
function _relocate_help_relocate_print_additional_set_env() {
    _relocate_help_relocate_print_additional "$1"
    cat << +++EOF+++
In addition, if and only if the combination of 'alias' and all of
the 'subdir-prefix'es do correspond to a directory then the
following environment variables are set: 'r2' is set to the value
of the environment variable 'r1' if 'r1' is set, 'r1' is set to
the value of the environment variable 'rp' if 'rp' is set, and
then 'rp' is set to the directory that we wrote to standard
output.

+++EOF+++
}


## Outputs to standard output the help message for the _relocate_additional()
## function.
#
# See also: _relocate_additional().
#
# usage: _relocate_help_relocate_additional name
function _relocate_help_relocate_additional() {
    cat << +++EOF+++
usage $1 alias [subdir-prefix ...]

where 'alias' is the relocation alias of the directory to
relocate to, unless one or more 'subdir-prefix'es are specified,
in which case we relocate to the following directory:

    - if there is one 'subdir-prefix', the first subdirectory of
      of the directory corresponding to the relocation alias
      'alias' that starts with 'subdir-prefix'; otherwise

    - if there are 'n' 'subdir-prefix'es 'prefix-1', ...,
      'prefix-n' (where n > 1), the first subdirectory of the
      directory that 'alias' and the first n-1 'subdir-prefix'es
      would have relocated us to that starts with 'prefix-n'.

If one of the 'subdir-prefix'es doesn't match any subdirectories
of the appropriate directory then the pathname of that directory
will be output in an error message (so the caller has the option
of relocating to the last matching subdirectory).

A prefix is matched against a directory's subdirectories as
follows: if one or more subdirectories start with the prefix
then those are the matches to the prefix; otherwise if caseless
matches are allowed and one or more start with the prefix -
ignoring any differences in case - then those are the matches to
the prefix; otherwise if the prefix contains one or more dots
(.) and one or more subdirectories start with the prefix if we
allow each dot to match any sequence of zero or more characters
then those are the matches to the prefix; otherwise if the prefix
doesn't start with a dot and one or more subdirectories contain
the prefix if we allow each dot to match any sequence of zero or
more characters then those are the matches to the prefix.

Note: if 'alias' is '.' (which is not a valid user-defined alias,
and so cannot conflict with one) then it is treated as being an
alias for the current working directory. And if 'alias' is '/'
(which is also not a valid user-defined alias) then it is treated
as being an alias for the root directory.

+++EOF+++
}


## Outputs to standard output the help message for the
## _relocate_additional_set_env() function.
#
# See also: _relocate_additional_set_env().
#
# usage: _relocate_help_relocate_additional_set_env name
function _relocate_help_relocate_additional_set_env() {
    _relocate_help_relocate_additional "$1"
    cat << +++EOF+++
In addition, if and only if we change to a different directory
from the following environment variables are set: 'rr' is set to
the old current working directory, and 'r' is set to the new
current working directory. No environment variables are modified
if we didn't change to a different directory.

+++EOF+++
}


## Outputs to standard output the help message for the _relocate_set()
## function.
#
# See also: _relocate_set().
#
# usage: _relocate_help_relocate_set name
function _relocate_help_relocate_set() {
    cat << +++EOF+++
usage: $1 [-f] alias dir

where 'alias' is the relocation alias to be set, and 'dir' is the
pathname of the directory that 'alias' is to be an alias for if
either the '-f' option is specified or if 'alias' isn't already
a relocation alias for a directory. Otherwise an error message is
output.

If 'dir' is '.' then the directory that 'alias' will alias is the
absolute pathname of the current working directory.

Note: the mappings from aliases to directories are stored in a
file named .relocations in a user's home directory. If you want
to remove a mapping without replacing it then you must (at
least currently) edit that file manually to remove it.

+++EOF+++
}


## Outputs to standard output the help message for the _relocate_print_env()
## function.
#
# See also: _relocate_print_env().
#
# usage: _relocate_help_relocate_print_env name
function _relocate_help_relocate_print_env() {
    cat << +++EOF+++
usage: $1

Writes to the standard output the current values of all of the
environment variables that can be modified by one or more
relocation-related functions.

+++EOF+++
}


## Outputs to standard output the help message for the _relocate_find()
## function.
#
# See also: _relocate_find().
#
# usage: _relocate_help_relocate_find name
function _relocate_help_relocate_find() {
    cat << +++EOF+++
usage: $1 pattern

where 'pattern' is the regular expression pattern to grep for in
the space separated list of all of the relocation aliases and the
directories that they alias.

+++EOF+++
}


## Outputs to standard output the help message for the
## _relocate_long_rp_list() function.
#
# See also: _relocate_long_rp_list().
#
# usage: _relocate_help_long_rp_list name
function _relocate_help_long_rp_list() {
    cat << +++EOF+++
usage: $1 [option ...] [file ...]

where 'option ...' and 'file ...' are options and filenames,
respectively, that will be passed to the 'ls' command as part of
writing to standard output a long listing of the contents of the
directory whose name the environment variable named "rp" expands
to.

An error message is output if the environment variable "rp"
isn't set.

+++EOF+++
}


## Outputs to standard output the help message for the
## _relocate_short_rp_list() function.
#
# See also: _relocate_short_rp_list().
#
# usage: _relocate_help_short_rp_list name
function _relocate_help_short_rp_list() {
    cat << +++EOF+++
usage: $1 [option ...] [file ...]

where 'option ...' and 'file ...' are options and filenames,
respectively, that will be passed to the 'ls' command as part of
writing to standard output a short listing of the contents of the
directory whose name the environment variable named "rp" expands
to.

An error message is output if the environment variable "rp"
isn't set.

+++EOF+++
}


## Outputs to standard output the help message for the
## _relocate_long_rr_list() function.
#
# See also: _relocate_long_rr_list().
#
# usage: _relocate_help_long_rr_list name
function _relocate_help_long_rr_list() {
    cat << +++EOF+++
usage: $1 [option ...] [file ...]

where 'option ...' and 'file ...' are options and filenames,
respectively, that will be passed to the 'ls' command as part of
writing to standard output a long listing of the contents of the
directory whose name the environment variable named "rr" expands
to.

An error message is output if the environment variable "rr"
isn't set.

+++EOF+++
}


## Outputs to standard output the help message for the
## _relocate_short_rr_list() function.
#
# See also: _relocate_short_rr_list().
#
# usage: _relocate_help_short_rr_list name
function _relocate_help_short_rr_list() {
    cat << +++EOF+++
usage: $1 [option ...] [file ...]

where 'option ...' and 'file ...' are options and filenames,
respectively, that will be passed to the 'ls' command as part of
writing to standard output a short listing of the contents of the
directory whose name the environment variable named "rr" expands
to.

An error message is output if the environment variable "rr"
isn't set.

+++EOF+++
}


##
## User interface functions.
##

## Provides the user interface to _relocate_print_additional().
#
# See also: _relocate_print_additional().
function _relocate_user_print_additional() {
    local name='_relocate_print_additional'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_print_additional "$name"
            return 0
        fi
    fi
    _relocate_print_additional $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_print_additional "$name" >&2
    fi
    return $rc
}


## Provides the user interface to _relocate_print_additional_set_env().
#
# See also: _relocate_print_additional_set_env().
function _relocate_user_print_additional_set_env() {
    local name='_relocate_print_additional_set_env'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_print_additional_set_env "$name"
            return 0
        fi
    fi
    _relocate_print_additional_set_env $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_print_additional_set_env "$name" >&2
    fi
    return $rc
}


## Provides the user interface to _relocate_additional().
#
# See also: _relocate_additional().
function _relocate_user_additional() {
    local name='_relocate_additional'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_additional "$name"
            return 0
        fi
    fi
    _relocate_additional $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_additional "$name" >&2
    fi
    return $rc
}

## Provides the user interface to _relocate_additional_set_env().
#
# See also: _relocate_additional_set_env().
function _relocate_user_additional_set_env() {
    local name='_relocate_additional_set_env'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_additional_set_env "$name"
            return 0
        fi
    fi
    _relocate_additional_set_env $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_additional_set_env "$name" >&2
    fi
    return $rc
}


## Provides the user interface to _relocate_print_env().
#
# See also: _relocate_print_env().
function _relocate_user_print_env() {
    local name='_relocate_print_env'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_print_env "$name"
            return 0
        fi
    fi
    _relocate_print_env $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_print_env "$name" >&2
    fi
    return $rc
}


## Provides the user interface to _relocate_set().
#
# See also: _relocate_set().
function _relocate_user_set() {
    local name='_relocate_set'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_set "$name"
            return 0
        fi
    fi

    local rc=0
    if [ $# -gt 0 ]
    then
        _relocate_set $*
        rc=$?
    else
        # No alias was defined.
        _relocate_update_all_completions
        rc=$?
    fi
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_set "$name" >&2
    fi
    return $rc
}


## Provides the user interface for searching for a pattern in the list of
## relocation aliases and the directories that they alias.
function _relocate_user_find() {
    local name='_relocate_find'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_relocate_find "$name"
            return 0
        fi
    fi
    _relocate_find $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_relocate_find "$name" >&2
    fi
    return $rc
}


## Provides the user interface for printing a long list of the contents of
## the directory that the environment variable "rp" expands to.
function _relocate_user_long_rp_list() {
    local name='_relocate_long_rp_list'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_long_rp_list "$name"
            return 0
        fi
    fi
    _relocate_long_rp_list $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_long_rp_list "$name" >&2
    fi
    return $rc
}


## Provides the user interface for printing a short list of the contents of
## the directory that the environment variable "rp" expands to.
function _relocate_user_short_rp_list() {
    local name='_relocate_short_rp_list'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_short_rp_list "$name"
            return 0
        fi
    fi
    _relocate_short_rp_list $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_short_rp_list "$name" >&2
    fi
    return $rc
}


## Provides the user interface for printing a long list of the contents of
## the directory that the environment variable "rr" expands to.
function _relocate_user_long_rr_list() {
    local name='_relocate_long_rr_list'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_long_rr_list "$name"
            return 0
        fi
    fi
    _relocate_long_rr_list $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_long_rr_list "$name" >&2
    fi
    return $rc
}


## Provides the user interface for printing a short list of the contents of
## the directory that the environment variable "rr" expands to.
function _relocate_user_short_rr_list() {
    local name='_relocate_short_rr_list'
    if [ $# -gt 0 -a "x$1" = "x-N" ]
    then
        shift
        if [ $# -gt 0 ]
        then
            name="$1"
            shift
        fi
    fi

    if [ $# -gt 0 ]
    then
        _relocate_is_help_option "$1"
        if [ $? -eq 0 ]
        then
            echo
            _relocate_help_short_rr_list "$name"
            return 0
        fi
    fi
    _relocate_short_rr_list $*
    local rc=$?
    if [ $rc -eq ${_relocate_misused_return_code} ]
    then
        _relocate_help_short_rr_list "$name" >&2
    fi
    return $rc
}


##
## Short and Long Aliases.
##

## Define the common relocation-related aliases.
alias relocate-update-completions=_relocate_update_all_completions
_relocate_all_completion_commands=""


_isConfigValid="y"
_doDefineShortAliases="${RELOCATE_DEFINE_SHORT_ALIASES:-y}"
if [ "${_doDefineShortAliases}" != "y" ] && [ "${_doDefineShortAliases}" != "n" ]
then
    _isConfigValid="n"
    cat >&2 << +++EOF+++

RELOCATE_DEFINE_SHORT_ALIASES must be set to 'y' (the default) or 'n':
'${_doDefineShortAliases}' is an invalid value for it.

+++EOF+++
fi

_doModifyEnv="${RELOCATE_MODIFY_ENVIRONMENT:-y}"
if [ "${_doModifyEnv}" != "y" ] && [ "${_doModifyEnv}" != "n" ]
then
    _isConfigValid="n"
    cat >&2 << +++EOF+++

RELOCATE_MODIFY_ENVIRONMENT must be set to 'y' (the default) or 'n':
'${_doModifyEnv}' is an invalid value for it.

+++EOF+++
fi

if [ "${_isConfigValid}" = "y" ]
then
    if [ "${_doDefineShortAliases}" = "y" ]
    then
        # Define the common short relocation-related aliases (regardless of
        # whether we modify the environment or not).
        alias rg='_relocate_user_find -N rg'
            ## Finds matches for the specified pattern in the list of
            ## relocation aliases and the directories that they alias.
            #
            # See also: _relocate_find.
        alias re='_relocate_user_print_env -N re'
            ## Outputs the names and values of the environment variables that
            ## can be set or modified by the relocation commands.
            #
            # See also: _relocate_print_env.
        alias rs='_relocate_user_set -N rs'
            ## Defines the specified name to be an alias for the specified
            ## directory.
            #
            # Note: a common use case is to 'cd' (or relocate) to the
            # directory and then execute 'rs name .', where 'name' is the
            # name of the relocation alias that's to be defined.
            #
            # See also: _relocate_set.
        alias rr='r .'
            ## Relocate relative to the current directory.

        # Note: 're' doesn't use relocation aliases.
        relocate_add_completion_command "rg"
        relocate_add_completion_command "rs"

        alias lrp='_relocate_user_long_rp_list -N lrp'
            ## Outputs a long listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rp'.
            #
            # This is more or less the same as 'ls -l $rp'.
            #
            # See also: lrr, lsrp, _relocate_long_rp_list.
        alias lsrp='_relocate_user_short_rp_list -N lsrp'
            ## Outputs a short listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rp'.
            #
            # This is more or less the same as 'ls $rp'.
            #
            # See also: lsrr, lrp, _relocate_short_rp_list.
        alias lrr='_relocate_user_long_rr_list -N lrr'
            ## Outputs a long listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rr'.
            #
            # This is more or less the same as 'ls -l $rr'.
            #
            # See also: lrp, lsrr, _relocate_long_rr_list.
        alias lsrr='_relocate_user_short_rr_list -N lsrr'
            ## Outputs a short listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rr'.
            #
            # This is more or less the same as 'ls $rr'.
            #
            # See also: lrr, lsrp, _relocate_short_rr_list.

        if [ "${_doModifyEnv}" = "y" ]
        then
            # Define a standard set of short relocation-related aliases for
            # relocation commands that can also modify the environment.
            alias r='_relocate_user_additional_set_env -N r'
                ## Changes the current directory to be the one corresponding
                ## to the specified relocation alias combined with any and
                ## all specified subdirectory prefixes, potentially setting
                ## or changing some environment variables in the process.
                #
                # See also: _relocate_additional_set_env.
            alias rp='_relocate_user_print_additional_set_env -N rp'
                ## Outputs the directory corresponding to the specified
                ## relocation alias combined with any and all specified
                ## subdirectory prefixes, potentially setting or changing
                ## some environment variables in the process.
                #
                # See also: _relocate_print_additional_set_env.
        else
            # Define a standard set of short relocation-related aliases for
            # relocation commands that do *not* modify the environment.
            alias r='_relocate_user_additional -N r'
                ## Changes the current directory to be the one corresponding
                ## to the specified relocation alias combined with any and
                ## all specified subdirectory prefixes.
                #
                # See also: _relocate_additional.
            alias rp='_relocate_user_print_additional -N rp'
                ## Outputs the directory corresponding to the specified
                ## relocation alias combined with any and all specified
                ## subdirectory prefixes.
                #
                # See also: _relocate_print_additional.
        fi

        # Note: 'rr' doesn't use relocation aliases.
        relocate_add_completion_command "r"
        relocate_add_completion_command "rp"
    else  # don't define short aliases: define long ones instead
        # Define the common long relocation-related aliases (regardless of
        # whether we modify the environment or not).
        alias relocate-find='_relocate_user_find -N relocate-find'
            ## Finds matches for the specified pattern in the list of
            ## relocation aliases and the directories that they alias.
            #
            # See also: _relocate_find.
        alias relocate-env='_relocate_user_print_env -N relocate-env'
            ## Outputs the names and values of the environment variables that
            ## can be set or modified by the relocation commands.
            #
            # See also: _relocate_print_env.
        alias relocate-set='_relocate_user_set -N relocate-set'
            ## Defines the specified name to be an alias for the specified
            ## directory.
            #
            # Note: a common use case is to 'cd' (or relocate) to the
            # directory and then execute 'rs name .', where 'name' is the
            # name of the relocation alias that's to be defined.
            #
            # See also: _relocate_set.

        # Note: 'relocate-env' doesn't use relocation aliases.
        relocate_add_completion_command "relocate-find"
        relocate_add_completion_command "relocate-set"

        # Note: unlike the short aliases, these are considerably longer than the
        # equivalent "ls $rp" or "ls -l $rp" commands they (essentially) alias.
        alias relocate-long-list-rp='_relocate_user_long_rp_list -N relocate-long-list-rp'
            ## Outputs a long listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rp'.
            #
            # This is more or less the same as 'ls -l $rp'.
            #
            # See also: relocate-long-list-rr, relocate-short-list-rp, _relocate_long_rp_list.
        alias relocate-short-list-rp='_relocate_user_short_rp_list -N relocate-short-list-rp'
            ## Outputs a short listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rp'.
            #
            # This is more or less the same as 'ls $rp'.
            #
            # See also: relocate-short-list-rr, relocate-long-list-rp, _relocate_short_rp_list.
        alias relocate-long-list-rr='_relocate_user_long_rr_list -N relocate-long-list-rr'
            ## Outputs a long listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rr'.
            #
            # This is more or less the same as 'ls -l $rr'.
            #
            # See also: relocate-long-list-rp, relocate-short-list-rr, _relocate_long_rr_list.
        alias relocate-short-list-rr='_relocate_user_short_rr_list -N relocate-short-list-rr'
            ## Outputs a short listing of the contents of the directory whose
            ## pathname is the value of the environment variable 'rr'.
            #
            # This is more or less the same as 'ls $rr'.
            #
            # See also: relocate-long-list-rr, relocate-short-list-rp, _relocate_short_rr_list.

        if [ "${_doModifyEnv}" = "y" ]
        then
            # Define a standard set of long relocation-related aliases for
            # relocation commands that can also modify the environment.
            alias relocate='_relocate_user_additional_set_env -N relocate'
                ## Changes the current directory to be the one corresponding
                ## to the specified relocation alias combined with any and
                ## all specified subdirectory prefixes, potentially setting
                ## or changing some environment variables in the process.
                #
                # See also: _relocate_additional_set_env.
            alias relocate-print='_relocate_user_print_additional_set_env -N relocate-print'
                ## Outputs the directory corresponding to the specified
                ## relocation alias combined with any and all specified
                ## subdirectory prefixes, potentially setting or changing
                ## some environment variables in the process.
                #
                # See also: _relocate_print_additional_set_env.
        else
            # Define a standard set of long relocation-related aliases for
            # relocation commands that do *not* modify the environment.
            alias relocate='_relocate_user_additional -N relocate'
                ## Changes the current directory to be the one corresponding
                ## to the specified relocation alias combined with any and
                ## all specified subdirectory prefixes.
                #
                # See also: _relocate_additional.
            alias relocate-print='_relocate_user_print_additional -N relocate-print'
                ## Outputs the directory corresponding to the specified
                ## relocation alias combined with any and all specified
                ## subdirectory prefixes.
                #
                # See also: _relocate_print_additional.
        fi
        relocate_add_completion_command "relocate"
        relocate_add_completion_command "relocate-print"
    fi
fi  # _isConfigValid = "y"
