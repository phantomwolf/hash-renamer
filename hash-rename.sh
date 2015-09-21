#!/bin/bash

usage()
{
    cat <<END
Usage: $0 [OPTIONS] FILE...

Options:
    -f, --force             Replace files with the same name
    -s, --format-string     %h represents for hash value
    -t, --hash-type         Hash algorithm to use
    -h, --help              Print usage info
    -v, --verbose           Verbose mode
END
}

# Get file sum, md5sum, sha1sum, sha224, sha256sum, sha384sum, sha512sum
# $1:       file to be hashed
# $2:       hash type
# output:   hash value
# return:   exit status of <xxx>sum or 255 if the file is missing
hashsum()
{
    if [[ -f "$1" ]]; then
        ${2}sum "$1" 2> /dev/null | awk '{print $1}'
        return $?
    else
        echo "Couldn't find $1" 1>&2
        return 255
    fi
}


# Generate file path according to dirname, sum value, sequence, extension name
# $1:   dirname
# $2:   sum value
# $3:   sequence
# $4:   extension name
path_gen()
{
    local path=""
    [[ -n "$1" ]] && path="${1}/"
    [[ -z "$2" ]] && return 255
    path="${path}$2"
    [[ -n "$3" ]] && path="${path}-$3"
    [[ -n "$4" ]] && path="${path}.$4"
    echo "$path"
    return 0
}


# Rename a file
# $1:   file path
# $2:   overwrite existing file?
# $3:   hash algorithm
rename_file()
{
    local path=`realpath "$1"`
    local overwrite=$2
    local algorithm=$3
    local dirname=`dirname "$path"`
    local basename=`basename "$path"`
    # If no extension names
    local extname="${basename##*.}"
    [[ "$extname" == "$basename" ]] && extname=""
    # Get sum value
    sum=`hashsum "$path" "$algorithm"`
    if [[ $? -ne 0 ]]; then
        echo "Failed to get ${OPTIONS[type]}sum value of $path" 1>&2
        return 1
    fi

    local target=`path_gen "$dirname" "$sum" "" "$extname"`
    target=`realpath "$target"`
    if [[ "$target" == "$path" ]]; then
        echo "Skip $target: file already renamed"
        return 0
    elif [[ "$overwrite" == "true" ]]; then
        rm -rf "$target"
    else
        local seq=1
        while [[ -e "$target" ]]; do
            target=`path_gen "$dirname" "$sum" "$seq" "$extname"`
            ++seq
        done
    fi
    mv "$path" "$target"
    return $?
}


# Rename an entry(directory or file)
# $1:   entry path
# $2:   overwrite existing files. Default: false
# $3:   hash algorithm
# $4:   recursive. Default: true
rename_entry()
{
    local path="$1"
    local overwrite=$2
    local algorithm=$3
    local recursive=${4:-true}
    if [[ -f "$path" ]]; then
        rename_file "$path" "$overwrite" "$algorithm"
    elif [[ -d "$path" ]]; then
        find "$path" -type f | while read item
        do
            rename_file "$item" "$overwrite" "$algorithm"
        done
    else
        echo "Skip: $path"
    fi
    return 0
}

################################################################################
################################# Main Entrance ################################
################################################################################
# parse arguments
declare -A OPTIONS
# default settings
OPTIONS[type]="sha1"
OPTIONS[string]=""
OPTIONS[overwrite]="true"
OPTIONS[verbose]="false"

ARGS=$(getopt -o v -l hash-type:,format-string:,recursive,overwrite,verbose,help -o t:,s:,r,f,v,h -- "$@")
eval set -- "${ARGS}"
while true; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -t|--hash-type)
            OPTIONS[type]=$2
            shift 2
            ;;
        -s|--format-string)
            OPTIONS[string]=$2
            shift 2
            ;;
        -r|--recursive)
            OPTIONS[recursive]=$2
            shift 2
            ;;
        -f|--overwrite)
            OPTIONS[overwrite]=true
            shift 1
            ;;
        -v|--verbose)
            OPTIONS[verbose]=true
            shift 1
            ;;
        --)
            shift
            break
            ;;
    esac
done

# Handle each file
for (( i=1; i <= $#; ++i ))
do
    entry=${!i}
    rename_entry "$entry" "${OPTIONS[overwrite]}" "${OPTIONS[type]}" "${OPTIONS[recursive]}"
    [[ $? -ne 0 ]] && echo "Failed to rename: $entry" 1>&2
done
