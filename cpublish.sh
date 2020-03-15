#!/bin/bash
die() {
    local -i code
    local msg
    code=$1
    shift
    msg=$*
    echo "ERROR! - $msg" >&2
    # shellcheck disable=SC2086
    exit $code
}

urlencode() {
    local string
    string=$*
    # Expect a wall of sed here, or a tool/external replacement
    # shellcheck disable=SC2001
    echo "$string" | sed -e 's/ /+/g'
}

# Where confluence's webdav directory is mounted
: "${CONFLUENCE_ROOT:=$HOME/confluence/dav}"

file=$1
[ -z "$file" ] && die 1 "Must pass a single filename as an argument"
[ -f "$file" ] || die 2 "No such file: '$file'"

# URL of the Confluence wiki server, derived from $CONFLUENCE_ROOT
conf_dav_url=$(df | awk -v conf_dir="$CONFLUENCE_ROOT" '$NF==conf_dir{print $1}')
[ -z "$conf_dav_url" ] && die 3 "Unable to find confluence mount point '$CONFLUENCE_ROOT' in \`df\`"

# File's basename
just_file=${file##*/}

# File's basename with no extension
file_without_extension=${just_file%%.*}

# Local directory
local_dir=$(realpath "$(dirname "$file")")

# Local directory with ^/Global/ removed
local_without_global=${local_dir##*/Global/}

# Confluence dav directory
wiki_root=${local_without_global%%/*}

# Confluence published URL
conf_view_url=${conf_dav_url%*/plugins/servlet/confluence/default}/display/$(urlencode "$wiki_root")/$(urlencode "$file_without_extension")

# Local root
local_root=Global/$local_without_global

# Confluence Publish Directory
confluence_input="$CONFLUENCE_ROOT/$local_root/$just_file"

# Confluence Publish File
confluence_txt=${confluence_input%.*}.txt

# Publish the file to Confluence
cp -v "$file" "$confluence_txt"

# Show the Published URL
echo "$conf_view_url"
