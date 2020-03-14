#!/bin/bash
usage() {
    echo "$0" PATH
    echo
    echo PATH is the path to a confluence directory under the Global namespace
}

die() {
    local -i code
    local msg
    code=$1
    msg=$2
    echo "ERROR! : $msg" >&2
    echo >&2 usage >&2
    # shellcheck disable=SC2086
    exit $code
}

for arg
do
    shift
    if [ "$arg" = "--dry-run" ]
    then
        dry_run=true
        continue
    fi
    set -- "$@" "$arg"
done

# Now $1 is the only arg we accept (a directory)
confluence_path=$1
[ -z "$confluence_path" ] && die 1 "No PATH given"
shift

# Now we should not have any args left
[ -n "$*" ] && die 4 "Extra args detected: $*"

# Sanity checks
[ -e "$confluence_path" ] || die 2 "$confluence_path does not exist"
[ -d "$confluence_path" ] || die 3 "$confluence_path is not a directory"

local_path=Global/${confluence_path#*Global/}
rsync --dry-run \
    -a --verbose --exclude="@versions/" --exclude="@exports/" \
    --include="*/" --include="*.txt" --exclude="*" \
    "$confluence_path" "$local_path"  | while read -r line
    do
        [[ "$line" =~ \.txt$ ]] || continue

        filename=${line##*/}
        conf_file=${confluence_path}/${filename}
        local_dir=Global/${confluence_path#*Global/}
        local_basedir=${local_dir%/*}
        local_fullpath="$local_basedir/$line"
        local_dirname=${local_fullpath%/*}
        if [ -n "$dry_run" ]
        then
            [ -d "$local_dirname" ] || echo "'$local_dirname' (Directory) will be created"
            echo "'$conf_file' will be linked to '$local_dirname/$filename'"
        else
            [ -d "$local_dirname" ] || mkdir -vp "$local_dirname"
            ln -vs "$conf_file" "$local_dirname/$filename"
        fi
    done
