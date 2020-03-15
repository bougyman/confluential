#!/bin/bash
urlencode() {
    local string
    string=$*
    # Expect a wall of sed here, or a tool/external replacement
    # shellcheck disable=SC2001
    echo "$string" | sed -e 's/ /+/'
}
: "${CONFLUENCE_ROOT:=$HOME/confluence/dav}"
conf_dav_url=$(df | awk -v conf_dir="$CONFLUENCE_ROOT" '$NF==conf_dir{print $1}')
conf_view_url=${conf_dav_url%*/plugins/servlet/confluence/default}/display
file=$1
shift
just_file=${file##*/}
file_without_extension=${just_file%%.*}
local_dir=$(realpath "$(dirname "$file")")
local_without_global=${local_dir##*/Global/}
wiki_root=${local_without_global%%/*}
local_root=Global/$local_without_global
confluence_input="$CONFLUENCE_ROOT/$local_root/$just_file"
confluence_txt=${confluence_input%.*}.txt
echo cp -v "$file" "$confluence_txt"
echo "$conf_view_url/$wiki_root/$(urlencode "$file_without_extension")"
