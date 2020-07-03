#!/bin/bash

################################################
#              lhlhx/AUTO-DIGv2 Alpha          #
#                Created by lhlhx              #
#                   MIT-License                #
#                                              #
#  Usage:                                      #
#  ./autodig.sh 1 <input.txt> <output.txt>     #
#  - Retrieving all answers based on input.txt #
#    Output all answers to output.txt          #
#                                              #
#  ./autodig.sh 0 <input.txt> <output.txt>     #
#  - Verifying all answers based on input.txt  #
#    (Obtained from first command)             #
################################################

# TODO: Inspect IPv6


# User Definition
DEBUG_LEVEL=2
DNS_SERVER="1.1.1.1"
DNS_SERVER_TIMEOUT=1


# System variables
__array_list=()
__input_file=""
__output_file=""
__service_option=0

__total_input_record=0
__total_walkthrough_record=0
__total_correct_record=0
__total_incorrect_record=0

# Log Printer
function func_log_print() {
    if [[ $DEBUG_LEVEL -lt 0 ]]; then
        echo "$(date) [ INFO  ] func_log_print: Log level cannot be less than 0, reset to 0."
        DEBUG_LEVEL=0
    fi

    case $1 in
        0)
            # WARNING Log
            if [[ $DEBUG_LEVEL -ge 0 ]]; then
                echo "$(date) [WARNING] $2"
            fi
            ;;
        1)
            # INFO Log
            if [[ $DEBUG_LEVEL -ge 1 ]]; then
                echo "$(date) [ INFO  ] $2"
            fi
            ;;
        2)
            # DEBUG Log
            if [[ $DEBUG_LEVEL -ge 2 ]]; then
                echo "$(date) [ DEBUG ] $2"
            fi
            ;;
        *)
            # UNKNOWN Log
            echo "$(date) [UNKNOWN] $2"
            ;;
    esac

}

# Inspect IPv4
function func_check_ipv4() {
    local ip=$1
    local state=1
 
    if [[ ${ip[0]} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        state=$?
    fi

    return $state
}

# TODO:Edit FQDN with ROOT
function func_beautify_line() {
    line=${line^l}
}

# Extract Values from one line
function func_get_value_from_line() {
    func_log_print 2 "func_get_value_from_line: Current Line | $line"
    OIFS=$IFS
    IFS=','
    line=($line)
    IFS=$OIFS

    state=$?
    return $state
}

function func_get_values_from_pre_array() {
    local array=$1
    local state=1

    OIFS=$IFS
    IFS=';'
    __array_list=($array)
    IFS=$OIFS
 
    state=$?
    return $state
}

# Set Script Global VariableS
## Set DNS Server
function func_set_dns_server() {
    local ip=$1
    # Check DNS Server IP
    if ! func_check_ipv4 $ip; then
        func_log_print 0 "func_set_dns_server: Input IP $ip is not valid, skip current line."
        return
    fi

    func_log_print 1 "func_set_dns_server: Change DNS server to $ip"
    DNS_SERVER=$ip

}
## Set __array_list in a Sorted manner
function func_set_array_sorted() {
    IFS=$'\n'
    __array_list=$(sort <<< "${__array_list[*]}")
    __array_list=($__array_list)
    unset IFS

    local state=$?

    func_log_print 2 "${FUNCNAME[0]}: Number of Roles: ${#__array_list[@]} __array_list: ${__array_list[*]}"
    return $state
}
# Verify Records
## Verify Generic Record
function func_verify_record() {
    local rtype=$1

    OIFS=$IFS
    IFS=$'\n'
    result=($( dig +short $rtype $hostname \@${DNS_SERVER}| sort ))
    IFS=$OIFS

    # For DNS Record Verification
    if [ $__service_option -eq 0 ];then
        if [[ ! ${#__array_list[@]} -eq ${#result[@]} ]]; then
                func_log_print 0 "${FUNCNAME[0]}: Number of answers are incorrect, FQDN=${hostname},RType=${rtype}"
                return
        fi

        local idx=0
        local correct_record=1
        for item in ${result[@]}; do
            if [[ "${__array_list[$idx]}" != "$item" ]]; then
                func_log_print 1 "${FUNCNAME[0]}: Incorrect answer, FQDN=${hostname},RType=${rtype},Expected=${__array_list[$idx]},Result=$item"
                echo "Incorrect,FQDN=${hostname},RType=${rtype},Expected=${__array_list[$idx]},Result=$item" >> $__output_file

                correct_record=0
            else
                func_log_print 1 "${FUNCNAME[0]}: Correct answer, FQDN=${hostname},RType=${rtype},Expected=${__array_list[$idx]},Result=$item"
                echo "Correct,FQDN=${hostname},RType=${rtype},Expected=${__array_list[$idx]},Result=$item" >> $__output_file
            fi

            ((idx++))
        done

        if [[ $correct_record -eq 1 ]]; then
            ((__total_correct_record++))
        else
            ((__total_incorrect_record++))
        fi
    else
    # For DNS Recorda retreival
        OIFS=$IFS
        IFS=';'
        echo "$rtype,$hostname,${result[*]}" >> $__output_file
        IFS=$OIFS
    fi
    ((__total_processed_record++))
}
## Verify A Record
function func_verify_record_a() {
    local hostname=$1
    local pre_array=$2

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return
    fi
    
    # Sort Array
    if ! func_set_array_sorted; then
        func_log_print 0 "${FUNCNAME[0]}: func_set_array_sorted failed, skip current line."
        return
    fi

    # Check if there are zero A records, if YES, return.
    if [[ ${#__array_list[@]} -lt 1 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: A has zero records, skip current line."
        return
    fi

    # Inspect Array, check if they are in correct IPv4 format.
    for answer in $__array_list; do
        if ! func_check_ipv4 $answer; then
            func_log_print 0 "${FUNCNAME[0]}: Input IP $answer is not valid, skip current row."
            continue
        fi
    done

    # answer_code="$(func_verify_record A)"
    func_verify_record "A"
    return
}
## Verify CNAME Record
function func_verify_record_cname() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi
    
    # Check if there are zero or more than one CNAME records, if YES, only process first CNAME record.
    if [[ ! ${#__array_list[@]} -eq 1 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: CNAME have zero or multiple records, only process first CNAME record."
    fi

    func_verify_record "CNAME"
    # answer_code=$(func_verify_record "CNAME")
    return $answer_code
}
## Verify PTR Record
function func_verify_record_ptr() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi
    
    # Check if there are zero or more than one PTR records, if YES, only process first PTR record.
    if [[ ! ${#__array_list[@]} -eq 1 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: PTR have zero or multiple records, only process first PTR record."
    fi

    func_verify_record "PTR"
    # answer_code=$(func_verify_record "PTR")
    return $answer_code
}
## Verify MX Record
function func_verify_record_mx() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi

    # Sort Array
    if ! func_set_array_sorted; then
        func_log_print 0 "${FUNCNAME[0]}: func_set_array_sorted failed, skip current line."
        return $answer_code
    fi

    
    # Check if there are zero MX records, if YES, return.
    if [[ ${#__array_list[@]} -eq 0 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: MX have zero records, skip current line."
    fi

    func_verify_record "MX"
    # answer_code=$(func_verify_record "NS")
    return $answer_code
}
## Verify TXT Record
function func_verify_record_txt() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi

    # Sort Array
    if ! func_set_array_sorted; then
        func_log_print 0 "${FUNCNAME[0]}: func_set_array_sorted failed, skip current line."
        return $answer_code
    fi

    
    # Check if there are zero TXT records, if YES, return.
    if [[ ${#__array_list[@]} -eq 0 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: TXT have zero records, skip current line."
    fi

    func_verify_record "TXT"
    # answer_code=$(func_verify_record "TXT")
    return $answer_code
}
## Verify NS Record
function func_verify_record_ns() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi

    # Sort Array
    if ! func_set_array_sorted; then
        func_log_print 0 "${FUNCNAME[0]}: func_set_array_sorted failed, skip current line."
        return $answer_code
    fi

    
    # Check if there are zero NS records, if YES, return.
    if [[ ${#__array_list[@]} -eq 0 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: NS have zero records, skip current line."
    fi

    func_verify_record "NS"
    # answer_code=$(func_verify_record "NS")
    return $answer_code
}
## Verify SRV Record
function func_verify_record_srv() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi

    # Sort Array
    if ! func_set_array_sorted; then
        func_log_print 0 "${FUNCNAME[0]}: func_set_array_sorted failed, skip current line."
        return $answer_code
    fi
    
    # Check if there are zero or more than one SRV records, if YES, only process first SRV record.
    if [[  ${#__array_list[@]} -eq 0 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: SRV have zero records, skip current line."
    fi

    #answer_code=$(func_verify_record "SRV")
    func_verify_record "SRV"
    #return $answer_code
}
## Verify SOA Record
function func_verify_record_soa() {
    local hostname=$1
    local pre_array=$2
    local answer_code=1

    # Get Array
    if ! func_get_values_from_pre_array "$pre_array"; then
        func_log_print 0 "${FUNCNAME[0]}: func_get_values_from_pre_array failed, skip current line."
        return $answer_code
    fi

    # Sort Array
    if ! func_set_array_sorted; then
        func_log_print 0 "${FUNCNAME[0]}: func_set_array_sorted failed, skip current line."
        return $answer_code
    fi
    
    # Check if there are zero or more than one SOA records, if YES, only process first SOA record.
    if [[  ${#__array_list[@]} -eq 0 ]]; then
        func_log_print 0 "${FUNCNAME[0]}: SOA have zero records, skip current line."
    fi

    #answer_code=$(func_verify_record "SOA")
    func_verify_record "SOA"
    #return $answer_code
}


# Main Service
## Get Records
function service_get_records() {
    local rtype=$1
    local hostname=$2

    func_log_print 2 "${FUNCNAME[0]}: Check RType: $rtype, Hostname: $hostname"
    func_verify_record $rtype
}
## Verify Records
function service_record_route() {
    IFS=$'\n'
    __input_file=($__input_file)
    __linefeed=$(cat $__input_file)

    for line in $__linefeed;do
        allowed_record=0
        func_log_print 2 "==================NEXT-LINE=================="
        func_beautify_line
        func_get_value_from_line

        rtype="${line[0]}"
        func_log_print 2 "Input RType $rtype"

        case $rtype in
            -)
                # TEXT Comment Line
                func_log_print 2 "Comment line, Skip."
                ;;

            DNSSRV)
                # DNSSRV: Change DNS Server
                # Schema: DNSSRV,<DNS SERVER IP>

                func_log_print 2 "Enter DNSSERV case."

                ip=${line[1]}

                func_set_dns_server $ip

                func_log_print 1 "Current DNS server is $DNS_SERVER"
                ;;

            A)
                # A: Verify A Record
                # Schema: A,<FQDN>,<IP 1>;<IP 2>;...;<IP n>

                func_log_print 2 "Enter A case."

                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_a "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;

            CNAME)
                # CNAME: Verify CNAME Record
                # Schema: CNAME,<FQDN>

                func_log_print 2 "Enter CNAME case."

                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_cname "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;

            PTR)
                # PTR: Verify PTR Record
                # Schema: PTR,<FQDN>

                func_log_print 2 "Enter PTR case."

                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_ptr "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;

            MX)
                # MX: Verify MX Record
                # Schema: MX,<FQDN>,<MX 1>;<MX 2>;...;<MX n>

                func_log_print 2 "Enter MX case."

                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_mx "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;

            TXT)
                # TXT: Verify TXT Record
                # Schema: TXT,<FQDN>,<TXT 1>;<TXT 2>;...;<TXT n>

                func_log_print 2 "Enter TXT case."

                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_txt "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;

            NS)
                # NS: Verify NS Record
                # Schema: NS,<FQDN>,<NS 1>;<NS 2>;...;<NS n>

                func_log_print 2 "Enter NS case."

                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_ns "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;

            SRV)
                # SRV: Verify SRV Record
                # Schema: SRV,<FQDN>,<SRV Record 1>;<SRV Record 2>;...;<SRV Record n>

                func_log_print 2 "Enter SRV case."
                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_srv "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;
            SOA)
                # SOA: Verify SOA Record
                # Note: RFC 1935 Exactly one SOA RR should be present at the top of the zone.
                # Schema: SOA,<FQDN>,<SOA Record 1>;<SOA Record 2>;...;<SOA Record n>

                func_log_print 2 "Enter SOA case."
                if [[ $__service_option -eq 0 ]]; then
                    hostname=${line[1]}
                    answer=${line[2]}
                    func_verify_record_soa "$hostname" "$answer"
                else
                    hostname=${line[1]}
                    allowed_record=1
                fi
                ;;
            *)
                # Unknown Record
                func_log_print 1 "RType $rtype is UNKNOWN, skip"
                continue
                ;;
            esac

            # For Service Get Records 
            if [ $allowed_record -eq 1 ] && [ $__service_option -eq 1 ]; then
                service_get_records "$rtype" "$hostname"
            fi
            ((__total_walkthrough_record++))
    done
    unset IFS
}

if [ ! -f $2 ]; then
    func_log_print 0 "Input File not found. Please Re-enter Filename:"

    echo "$(date) - ERROR: Output File not found."

    exit 1
fi

__input_file="$2"
__output_file="$3"

echo "Auto-DIG v2"

if [[ $1 -eq 0 && true ]]; then
    func_log_print 0 "Verifying Records with File $__input_file, Output File $__output_file"
    echo "-,$(date),Verification Report,Generated by autodig-v2" > $__output_file
    __service_option=0

else
    func_log_print 0 "Getting Records with File $__input_file, Output File $__output_file"
    echo "-,$(date),Batch record extraction,Generated by autodig-v2" > $__output_file
    __service_option=1
fi

service_record_route $__service_option $__input_file $__output_file

printf "%s %30s %s %30s %s\n" "Summary:" "Total number of Walkthrough Records:" "$__total_walkthrough_record" "Total number of Processed Records:" "$__total_processed_record"
if [[ $__service_option -eq 0 ]]; then
    printf "%s %10s %s %10s %s\n" "Total number of Incorrect Records:" "$__total_incorrect_record" "Total number of Correct Records:" "$__total_correct_record"
fi
