#!/usr/bin/env bash

# 05_top_ten_ip_barchart
# Report per-month HTTP log statistics for top 10 IP addresses in bar chart form

# POSIX conventions and the Shell Style Guide have been adhered to where viable
# https://google.github.io/styleguide/shell.xml

# Linted with shellcheck: https://github.com/koalaman/shellcheck

# On MacOS, install bash >= 4.0 with Homebrew. 
# YMMV.

# Read arguments and count into arrays to prevent them getting mangled
readonly SCRIPT_NAME=${0##*/}
readonly -a ARGV=("$@")
readonly ARGC=("$#")
readonly MIN_BASH_VERSION=4
readonly REQUIRED_COMMANDS="awk sort uniq head"
readonly START_YEAR=2015
readonly END_YEAR=2019
readonly START_MONTH=1
readonly END_MONTH=12
readonly MONTHS=( _ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ) 
# bash in particular needs a placeholder value as the first element 
# in the array
readonly BAR_GLYPH='#'
readonly ACCESS_LOG="access.log"


get_barchart_chars() {
    local num_chars="$1"
    local bar_char="$2"
    local char_count
    if [[ ${num_chars} -lt 1 || -z ${bar_char} ]]; then 
    # Haha no
        return 1
    fi

    for (( char_count = 0; char_count < num_chars; char_count++ )); do
        char_list+="${bar_char}"
    done
    printf "%s" "${char_list}"
}

main()
{
    local required_command
    local year
    local month
    local top_ten_ip_addresses
    local top_ten_ip_addresses_count
    local ip_address
    local ip_address_count
    local total_hits_per_period
    local column_length
    local top_list_item
    local count
    local ip_address
    local barchart_percentage

    if [[ "${BASH_VERSINFO[0]}" -lt "${MIN_BASH_VERSION}" ]]; then
        echo >&2 "Error: This script requires bash-4.0 or higher"
        exit 1
    fi

    # POSIX-compliant method for checking a command is available 
    for required_command in ${REQUIRED_COMMANDS}
    do
        if ! type "${required_command}" >/dev/null 2>&1; then
            echo >&2 "Error: This script requires ${required_command}"
            exit 1
        fi
    done

    echo "Top 10 IPs bar chart per month"
    for ((year=START_YEAR; year<=END_YEAR; year++)) 
    { 
    for ((month=START_MONTH; month<=END_MONTH; month++))
      {
        echo "${month[${START_MONTH}]}"

        top_ten_ip_addresses=()
        top_ten_ip_addresses_count=()
        while read -r ip_address ip_address_count;
        do
          top_ten_ip_addresses+=("${ip_address_count}")
          top_ten_ip_addresses_count+=("${ip_address}")
        done < <( 
        awk -v month_year="${MONTHS[${month}]}/${year}" \
        '$4 ~ month_year {print $1}' ${ACCESS_LOG} | \
        sort | \
        uniq -c | \
        sort -rn | \
        head -n 10 )

        # Let's not waste time, bail out now if there are no hits for
        # that period in the logs.
        if [[ ${#top_ten_ip_addresses[@]} -le 1 ]]; then
            echo "Zero matches in ${ACCESS_LOG} for ${MONTHS[${month}]}/${year}"
            break
        fi

        echo "${MONTHS[${month}]} ${year}"

        # Yes, this whole rigmarole again. 
        # We'll need it later for the bar chart calculation.
        total_hits_per_period=$(
        awk -v month_year="${MONTHS[${month}]}/${year}" \
        '$4 ~ month_year {print $1}' ${ACCESS_LOG} | wc -l)
        
        # Determine how many significant figures in first IP address count,
        # this will be needed for the printf() in the for loop later
        column_length=${#top_ten_ip_addresses_count[1]}
    
        for top_list_item in "${!top_ten_ip_addresses[@]}"; do

        count=${top_ten_ip_addresses_count[${top_list_item}]}
        ip_address=${top_ten_ip_addresses[${top_list_item}]}

        # bash arithmetic only supports integers, so use awk instead
        barchart_percentage=$(awk \
        -vtop="${total_hits_per_period}" \
        -vcount="${count}" \
        'BEGIN{printf("%.f\n",(count/top)*100)}')

        barchart=$(get_barchart_chars "${barchart_percentage}" "${BAR_GLYPH}")

        # Print a pretty table with the final scores
        printf "%${column_length}d\t%s\t(%s%%)\t%s\n" \
        "${count}"  \
        "${ip_address}" \
        "${barchart_percentage}" \
        "${barchart}" 
        done
      }
    }
}

main "${ARGV[@]}" 