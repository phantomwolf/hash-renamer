#!/bin/bash

# Get file sum, md5sum, sha1sum, sha224, sha256sum, sha384sum, sha512sum
# $1:       file to be hashed
# $2:       hash algorithm
# output:   hash value
# return:   exit status of <xxx>sum
hashsum()
{
    local output=`${2}sum "$1" 2> /dev/null`
    local exitstatus=$?
    [[ exitstatus -eq 0 ]] && echo "$output" | awk 'NR==1 {print $1}'
    return $exitstatus
}

# Generate file name according to pattern, and hash value
# $1:       format string
# $2:       hash value
# $3:       extname
# $4:       sequence num
# output:   file name
# return:   exitstatus of sed
gen_name()
{
    local name=`echo "$1" | sed -e "s/%h/${2}/g" 2> /dev/null`
    local exitstatus=$?
    [[ -n "$4" ]] && name="${name}-$4"
    [[ -n "$3" ]] && name="${name}.$3"
    echo "$name"
    return $exitstatus
}


# Join path parts
# $1...$n:      path parts
path_join()
{
    local path=""
    local item
    for item in "$@"; do
        if [[ "$path" != */ ]] && [[ "$item" != /* ]]; then
            path="$path/$item"
        else
            path="${path}${item}"
        fi
    done
    echo "$path" 2> /dev/null
    return $?
}


# Get extension name of a file
# $1:       file path
# output:   file's extension name; nothing if file has no extname
extname()
{
    local basename=`basename "$1"`
    local extname="${basename##*.}"
    if [[ "$extname" == "$basename" ]]; then
        return 1
    else
        echo "$extname"
        return 0
    fi
}


# Rename a file
# $1:   path
# $2:   format string
# $3:   hash algorithm
# $4:   overwrite existing files
rename_file()
{
    local path=`realpath "$1"`
    local dirname=`dirname "$path"`
    local basename=`basename "$path"`
    local extname=`extname "$path"`
    local format="$2"
    local hash_algorithm="$3"
    local overwrite="$4"
    # Get hash value
    local hash=`hashsum "$path" "$hash_algorithm"`
    if [[ $? -ne 0 ]]; then
        echo "Failed to get ${hash_algorithm}sum of $path" 1>&2
        return 1
    fi
    # Check if the file has already been renamed
    local name=`gen_name "$format" "$hash"`
    if [[ "$basename" == "${name}.${extname}" ]] ||
        [[ -n `echo "$basename" | grep -P "^${name}-\\d+\\.${extname}$"` ]]; then
        echo "Skipped $path"
        return 0
    fi
    name=`gen_name "$format" "$hash" "$extname"`
    local target=`path_join "$dirname" "$name"`
    if [[ -e "$target" ]]; then
        if [[ "$overwrite" == "true" ]]; then
            if [[ -f "$target" ]]; then
                rm -f "$target"
            else
                echo "Overwrite failed. Not a regular file: $target" 1>&2
                return 2
            fi
        else
            local -i seq=1
            while [[ -e "$target" ]]; do
                name=`gen_name "$format" "$hash" "$extname" "$seq"`
                target=`path_join "$dirname" "$name"`
                seq+=1
            done
        fi
    fi
    mv "$path" "$target"
    return $?
}


# Rename a directory
# $1:   Directory path
# $2:   The pattern used to search for files to be renamed
# $3:   Format string
# $4:   Hash algorithm
# $5:   Recursive
# $6:   Overwrite
# $7:   Options for 'find'
rename_dir()
{
    local path="$1"
    local pattern="$2"
    local format="$3"
    local hash_algorithm="$4"
    local recursive="$5"
    local overwrite="$6"
    local options="$7"

    if [[ ! -e "$path" ]]; then
        echo "No such directory: $path" 1>&2
        return 1
    fi
    if [[ ! -d "$path" ]]; then
        echo "Not a directory: $path" 1>&2
        return 2
    fi

    local cmd="find '$path'"
    [[ -n "$options" ]] && cmd="$cmd $options"
    [[ "$recursive" != "true" ]] && cmd="$cmd -maxdepth 1"
    [[ -n "$pattern" ]] && cmd="$cmd -name '$pattern'"
    cmd="$cmd -type f"
    eval "$cmd" | while read item; do
        rename_file "$item" "$format" "$hash_algorithm" "$overwrite"
    done
    return 0
}

# Print usage info
usage()
{
    cat <<END
Usage: $0 [OPTIONS] path [pattern]

Arguments:
    path                    File or directory
    pattern                 Pattern to filter files

Options:
    -k, --keep              Do not overwrite existing files
    -f, --format            Format string for file name(%h is interpreted to file hash value)
    -h, --hash              Hash algorithm(supported: sha1, sha224, sha256, sha384, sha512, md5, ck)
                            default: sha1
    -n, --non-recursive     Do not rename files in sub directories
    --help                  Print usage info
END
}

# Main function
main()
{
    # Parse arguments
    local path
    local pattern
    local -A opts
    # Default settings
    opts[hash]="sha1"
    opts[format]="%h"
    opts[overwrite]="true"
    opts[recursive]="true"
    
    local ARGS
    ARGS=$(getopt -l hash:,format:,non-recursive,keep,help -o h:,f:,n,k -- "$@")
    eval set -- "${ARGS}"
    while true; do
        case "$1" in
            --help)
                usage
                exit 0
                ;;
            -h|--hash)
                opts[hash]=$2
                shift 2
                ;;
            -f|--format)
                opts[format]=$2
                echo "${opts[format]}" | grep -q '%h'
                if [[ $? -ne 0 ]]; then
                    echo "Invalid format string: ${opts[format]}. Pattern must contain %h"
                    exit 255
                fi
                shift 2
                ;;
            -n|--non-recursive)
                opts[recursive]="false"
                shift 1
                ;;
            -k|--keep)
                opts[overwrite]="false"
                shift 1
                ;;
            --)
                shift
                break
                ;;
        esac
    done
    
    # Check if path is provided
    if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
        usage
        exit 255
    fi
    # Check if path exists
    if [[ ! -e "$1" ]]; then
        echo "No such file or directory: $1" 1>&2
        exit 1
    fi
    # Get path and pattern
    path="$1"
    [[ -n "$2" ]] && pattern="$2"
    # Rename files under directory
    rename_dir "$path" "$pattern" "${opts[format]}" "${opts[hash]}" "${opts[recursive]}" "${opts[overwrite]}"
    exit $?
}

main "$@"
