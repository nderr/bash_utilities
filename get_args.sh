#!/usr/bin/env bash

set -euo pipefail

get_args() {

	supports_enhanced_getopt() {

		# test for gnu enhanced getopt
		local ret=0
		(getopt -T > /dev/null) || ret=$?

    if [[ $ret -eq 4 ]]
    then
      echo 1
    elif [[ $ret -eq 0 ]]
    then
      echo ''
    else
      echo "Unexpected getopt return code $ret" >&2
      return 1
    fi
	}

	# check on args
	if [[ $# -lt 2 ]]
	then
		echo "Usage: get_args <long_opts> <reqd_args> [args...]" >&2
		return 1
	fi

	# script name
	local name=$(basename "$0")

	# grab long options and number of req'd args
	local long="$1"
	local reqd="$2"
	shift 2

	# append help option
	if [[ ! $long ]]
	then
		long=help
	else
		long+=",help"
	fi

	# long can only be letters, dashes, colons, commas
  if [[ ! $long =~ ^[a-zA-Z,-:]+$  ]]
	then
		echo "Error: long_opts can only contain letters, dashes, and commas." >&2
		return 1
	fi

	# and it can't start or end with a comma
	if [[ $long =~ ^,|,$ ]] 
	then
		echo "Error: long_opts can't start or end with a comma." >&2
		return 1
	fi


	# split "long" around commas and make the entries a bash array
	local _long
	IFS=',' read -r -a _long <<< "$long"

	# check if reqd is a number or a string
	if [[ $reqd =~ ^[0-9]+$ ]]
	then
		local nreq=$reqd
		declare -a _names
		for (( i=0; i<nreq; i++ ))
		do
			_names+=("arg$((i+1))")
		done
	elif [[ "$reqd" == '-' ]]
	then
		local nreq=-1
		local _names=""
	else

		# split "reqd" around commas and make the entries a bash array
		local _names
		IFS=',' read -r -a _names <<< "$reqd"
		local nreq=${#_names[@]}
	fi


	# make an array of whether an arg is required
	declare -a _short
	declare -a _arg

	local i
	for (( i=0; i<${#_long[@]}; i++ ))
	do

		# grab short option
		_short+=("${_long[i]:0:1}")

		# check if arg is required
		if [[ ${_long[i]: -1} == ':' ]]
		then
			_arg+=("1")
			_long[i]=${_long[i]::-1}
		else
			_arg+=("")
		fi
	done

	# concatenate the entries of _short into a str
	local short
	short=''
	for (( i=0; i<${#_short[@]}; i++ ))
	do

		local c
		c=${_short[i]}

		if [[ ${_arg[i]} ]]
		then
			short+="$c:"
		else
			short+="$c"
		fi
	done

	# parse args
	local TEMP
	if [[ $(supports_enhanced_getopt) ]]
	then
		TEMP=$(getopt -o $short -l $long -n $name -- $@)
	else
		TEMP=$(getopt "$short" "$@")
	fi 

	# check if successful
	if [[ $? -ne 0 ]]
	then
		echo "getopt failed, check call within get_args" >&2
		return 1
	fi

	print_help () {
		if [[ $_names ]]
		then
			printf "Usage: $name [options]"
			for (( i=0; i<${#_names[@]}; i++ )) {
				printf " <%s>" "${_names[i]}"
			}
			echo
		else
			echo "Usage: $name [options] args..." >&2
		fi
		echo '' >&2
		echo "Options:" >&2

		for (( i=0; i<${#_long[@]}; i++ ))
		do

			local c=${_short[i]}
			local opt=${_long[i]}
			local arg=${_arg[i]}

			if [[ $(supports_enhanced_getopt) ]]
			then
				if [[ $arg ]]
				then
					echo "  -$c, --$opt <arg>" >&2
				else
					echo "  -$c, --$opt" >&2
				fi
			else
				if [[ $arg ]]
				then
					echo "  -$c <arg>" >&2
				else
					echo "  -$c" >&2
				fi
			fi
		done
	}

	for (( i=0; i<${#_long[@]}; i++ ))
	do
		local c=${_short[i]}
		declare -g opt_$c=''
	done

	for (( i=0; i<${#_long[@]}; i++ ))
	do

		eval set -- "$TEMP"

		local c=${_short[i]}
		local opt=${_long[i]}
		local arg=${_arg[i]}

		# generate args
		while true
		do
			case "$1" in

				"-$c"|"--$opt")

					if [[ $arg ]]
					then
						declare -g opt_$c="$2"
						shift 2
						continue
					else
						declare -g opt_$c=1
						shift
						continue
					fi
				;;
				'--')
					shift
					break
				;;
				*)
					shift
					continue
				;;
			esac
		done
	done

  echo "$@"

	declare -g argv=("$@")
	declare -g argc=${#argv[@]}

	unset TEMP

	if [[ $opt_h ]]
	then
		print_help
		return 0
	fi

	# check on required number of args
	if [[ $nreq -ge 0 && $argc -ne $nreq ]]
	then
		echo "Error: $argc args provided, but $nreq required." >&2
		echo "" >&2
		print_help
		return 1
	fi

	if [[ $_names ]]
	then
		for (( i=0; i<${#_names[@]}; i++ )) {
			declare -g ${_names[i]}="${argv[i]}"
		}
	fi
}
