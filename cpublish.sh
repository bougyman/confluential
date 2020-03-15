#!/bin/bash
usage() {
    echo "$0 will publish a page to Confluence by copying a file to the Confluence dav directory."
    echo 
    echo "$0 FILE"
    echo 
    echo "FILE is the file to publish. It will be published to the Confluence path relative to Global"
    echo "Example: $0 Global/SpaceName/SubDirectory/PageName/PageName.xml"
    echo "FILE should be valid xhtml"
}

die() {
    local -i code
    local msg
    code=$1
    shift
    msg=$*
    echo "ERROR! - $msg" >&2
    echo >&2
    usage >&2
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

file=$1
[ -z "$file" ] && die 1 "Must pass a single filename as an argument"
[ -f "$file" ] || die 2 "No such file: '$file'"
which realpath 1>/dev/null 2>/dev/null || die 3 "'realpath' not found. Install realpath and try again"

# Where confluence's webdav directory is mounted
: "${CONFLUENCE_ROOT:=$HOME/confluence/dav}"

# URL of the Confluence wiki server, derived from $CONFLUENCE_ROOT
conf_dav_url=$(df | awk -v conf_dir="$CONFLUENCE_ROOT" '$NF==conf_dir{print $1}')
[ -z "$conf_dav_url" ] && die 4 "Unable to find confluence mount point '$CONFLUENCE_ROOT' in \`df\`"

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

# Local root
local_root=Global/$local_without_global

# Confluence Publish Directory
confluence_publish_directory=$CONFLUENCE_ROOT/$local_root

if [ ! -d "$confluence_publish_directory" ]
then
    echo "$confluence_publish_directory does not exist" >&2
    read -p "Would you like to create it? " -r yn
    if [[ "$yn" =~ ^[Yy][Ee][Ss] ]]
    then
        echo "Creating $confluence_publish_directory" >&2
        mkdir -vp "$confluence_publish_directory"
    else
        echo "Ok, bailing. Cannot publish without directory creation" >&2
        exit
    fi
fi

# Confluence Base Filename
confluence_input="$confluence_publish_directory/$just_file"

# Confluence Publish File
confluence_txt=${confluence_input%.*}.txt

# Publish the file to Confluence
cp -v "$file" "$confluence_txt" || die 5 "Failed to publish $confluence_txt"

# Confluence published URL
url_file=$CONFLUENCE_ROOT/$local_root/$just_file.url
if [ -f "$url_file" ]
then
    conf_view_url=$(awk -F'=' '$1==URL{print $2; exit}' "$url_file")
else
    # Fallback to default url template
    conf_view_url=${conf_dav_url%*/plugins/servlet/confluence/default}/display/$(urlencode "$wiki_root")/$(urlencode "$file_without_extension")
fi

# Show the Published URL
echo "$conf_view_url"
