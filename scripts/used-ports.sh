#!/bin/bash

# Colors
RESET="\033[0m"

BOLD="\033[1m"
DIM="\033[2m"
UNDERLINE="\033[4m"

BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"

BRIGHT_BLACK="\033[0;90m"
BRIGHT_RED="\033[0;91m"
BRIGHT_GREEN="\033[0;92m"
BRIGHT_YELLOW="\033[0;93m"
BRIGHT_BLUE="\033[0;94m"
BRIGHT_MAGENTA="\033[0;95m"
BRIGHT_CYAN="\033[0;96m"
BRIGHT_WHITE="\033[0;97m"


print_helper() {
	echo -e "${BOLD}$1${RESET} : List or get information about used ports

${BOLD}${BLUE}Usage:${RESET}
   -d,  --docker      Show only Docker containers
   -p,  --process     Show only system processes
   -c,  --compact     Compact view (just ports without name)
   -gr, --get-random  RANGE Get a random unused port
                      Range can be:
                         priviledged  0-1023
                         registered   1024-49151
                         dynamic      49152-65535
                         [MIN-MAX]    custom range, e.g., [9100-9200]
   -gp, --get-port    Filter output by specific port or process name
                      Can be a number (port) or a string (proc name)
   --help             Show this help message and exit

${BOLD}${BLUE}Notes:${RESET}
   You'll need to execute the command using sudo, since Docker need a
   root access.

${BOLD}${BLUE}Examples:${RESET}
   ${YELLOW}sudo $1${RESET}
      List all ports and associated processed or Docker containers

   ${YELLOW}sudo $1 -c${RESET}
      Show all used ports in a compact format
	
   ${YELLOW}sudo $1 -gr registered${RESET}
      Returns a random unused registered port (1024-49151)

   ${YELLOW}sudo $1 -gr [9100-9200]${RESET}
      Returns a random unused port in the custom range 9100-9200

   ${YELLOW}sudo $1 -gr [100:9000-9200,9400-9550]${RESET}
      Returns 100 consecutive ports in the range 9000-9200 or 9400-9550
      If there is not range, print a message

   ${YELLOW}sudo $1 -gp 80${RESET}
      Filters output for port 80

   ${YELLOW}sudo $1 -gp nginx${RESET}
      Filters output for the process named \"nginx\"
"
}


print_normal() {
	container=$(docker ps --format '{{.Names}} {{.Ports}}' | \
		grep -oP "^(\S+).*\b${port}->" | \
		awk '{print $1}')

	padding="   "
	printf "  ${padding}%-5.5s ${padding}%-7.7s${padding}%s\n" "PORTS" "TYPE" "NAME"
	if [ -n "$container" ]; then
		printf "${BOLD}=>${padding}%-5.5s${RESET} ${padding}${BLUE}%s${RESET}${padding}%s\n" "$port" "DOCKER " "$container"	
	else 
		proc=$(sudo ss -ltnpH | grep -m1 ":$port " | awk -F'"' '{print $2}')
		printf "${BOLD}=>${padding}%-5.5s${RESET} ${padding}${YELLOW}%s${RESET}${padding}%s\n" "$port" "PROCESS" "${proc:-unknown}"
	fi
}

print_compact() {
	container=$(docker ps --format '{{.Names}} {{.Ports}}' | \
		grep -oP "^(\S+).*\b${port}->" | \
		awk '{print $1}')

	if [ -n "$container" ]; then
		printf "%s " "$port"
	else
		proc=$(sudo ss -ltnpH | grep -m1 ":$port " | awk -F'"' '{print $2}')
		printf "%s " "$port"
	fi
}

parse_range() {
 	# $1 is a range
	# - [N:MIN1-MAX1,...,MINN-MAXN]
	# - default: no N
	local range="$1"
	local MIN MAX

	if [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
	MIN="${BASH_REMATCH[1]}"
	MAX="${BASH_REMATCH[2]}"

		if (( MIN > MAX )); then
			echo "Error: invalid range $range" >&2
			return 1
		fi

		echo "$MIN $MAX"
	else
		echo "Error: invalid format '$range'" >&2
		return 1
	fi
}

parse_ranges() {
	local input="$1"
	local N=""
	local body

	input="${input#[}"
	input="${input%]}"

	if [[ "$input" =~ ^([0-9]+):(.*)$ ]]; then
		N="${BASH_REMATCH[1]}"
		body="${BASH_REMATCH[2]}"
	else
		body="$input"
	fi

	echo "N ${N:-1}"

	IFS=',' read -ra parts <<< "$body"

	for part in "${parts[@]}"; do
		parse_range "$part" || return 1
	done
}

get_random_port() {
 	# 0-1023 : well-known ports
	# 1024-49151 : registered ports
	# 49152-65535 : dynamic/private ports
	local input="$1"
	local N=1
	local port
	local MIN MAX
	local ranges=()
	local candidates=()

	case "$input" in
		priviledged) input="[0-1023]" ;;
		registered)  input="[1024-49151]" ;;
		dynamic)     input="[49152-65535]" ;;
	esac

	mapfile -t used < <(ss -ltnpH | awk '{print $4}' | sed 's/.*://' | sort -u)
    
	declare -A used_map
	for p in "${used[@]}"; do
		used_map["$p"]=1
	done

	while read -r a b; do
		if [[ "$a" == "N" ]]; then
			N="$b"
		else
			ranges+=("$a $b")
		fi
	done < <(parse_ranges "$input") || return 1

	local found=false
	for r in "${ranges[@]}"; do
		read -r MIN MAX <<< "$r"
		(( MAX - MIN + 1 < N )) && continue

		for ((start=MIN; start<=MAX-N+1; start++)); do
			local ok=true
			for ((i=0; i<N; i++)); do
				if [[ -n "${used_map[$((start+i))]}" ]]; then
					ok=false
					break
				fi
			done
			if $ok; then
				found=true
				local result=()
				for ((i=0; i<N; i++)); do
					result+=("$((start+i))")
				done
				echo "${result[*]}"
				return 0
			fi
		done
	done
	
	if ! $found; then
 		echo "Error: unable to find $N consecutive free ports in given ranges" >&2
		return 1
	fi
 }

SHOW_DOCKER=false
SHOW_PROCESS=false
COMPACT=false
GET_RANDOM=""
RANDOM_MIN=0
RANDOM_MAX=0
GET_PORT=""

original_args=("$0")

while [[ $# -gt 0 ]]; do
    case "$1" in
		--docker | -d)
			SHOW_DOCKER=true
			shift
			;;
		--process | -p)
			SHOW_PROCESS=true
			shift
			;;
		--compact | -c)
			COMPACT=true
			shift
			;;
		--get-random | -gr)
			GET_RANDOM="$2"
			get_random_port "$GET_RANDOM"
			exit 0
			;;
		--get-port | -gp)
            GET_PORT="$2"
            shift 2
            ;;
		--get-port=* | -gp=*)
			GET_PORT="${1#*=}"
			shift
			;;
		--help)
			print_helper "$0"
			exit 0
			;;
 
		# Combined short flags
		-[!-]*)
			flags="${1#-}"
			for ((i=0; i<${#flags}; i++)); do
				case "${flags:$i:1}" in
					d) SHOW_DOCKER=true ;;
					s) SHOW_PROCESS=true ;;
					c) COMPACT=true ;;
					*)
						echo "Unknown flag: -${flags:$i:1}"
						exit 1
						;;
				esac
           	done
			shift
			;;

		*)
			echo "Unknown option: $1"
			exit 1
			;;
	esac
done

mapfile -t ports < <(
	sudo ss -ltnpH | 
	awk '{print $4}' | 
	sed 's/.*://' |
	sort -un
)

for port in "${ports[@]}"; do
	if $COMPACT; then
		print_compact
	elif [[ -n "$GET_PORT" ]]; then
		if [[ $GET_PORT =~ ^[0-9]+$ ]]; then
			print_normal | grep -E "(^|[^0-9])$GET_PORT([^0-9]|$)"
		else
			print_normal | grep -i -w "$GET_PORT"
		fi
	else
		print_normal
	fi
done | sort -u -k2,2n
