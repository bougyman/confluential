#!/bin/bash
: "${global:-Global}"

usage() {
    echo "$0 will publish a page to Confluence by copying a file to the Confluence dav directory."
    echo 
    echo "$0 FILE"
    echo 
    echo "FILE is the file to publish. It will be published to the Confluence path relative to $global"
    echo "Example: $0 $global/SpaceName/SubDirectory/PageName/PageName.xml"
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

local_dir=$(realpath "$(dirname "$file")")

if [[ "$local_dir" =~ /Personal/ ]]
then
    global=Personal
elif [[ "$local_dir" =~ /Global/ ]]
then
    global=Global
else
    die 5 "Could not find /Global/ nor /Personal/ in $local_dir"
fi

# Local directory with /Global/ or /Personal/ removed (depending on $global)
local_without_global=${local_dir##*/$global/}

# Confluence dav directory
wiki_root=${local_without_global%%/*}

# Local root
local_root=$global/$local_without_global

# Confluence Publish Directory
confluence_publish_directory=$CONFLUENCE_ROOT/$local_root

if [ "$global" == "Personal" ]
then
    confluence_publish_directory=$CONFLUENCE_ROOT/Personal/~$USER/$local_without_global
fi

# Confluence Directory Name
confluence_directory_name=${confluence_publish_directory##*/}

# Confluence bare filename
confluence_bare_filename=${confluence_publish_directory}/${confluence_directory_name}

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

# Confluence Publish File
confluence_txt=${confluence_bare_filename}.txt

# Publish the file to Confluence
cp -v "$file" "$confluence_txt" || die 6 "Failed to publish $confluence_txt"

# Confluence published URL
url_file=${confluence_bare_filename}.url
if [ -f "$url_file" ]
then
    conf_view_url=$(awk -F'=' '$1=="URL"{print $2; exit}' "$url_file")
    if [ -z "$conf_view_url" ]
    then
        echo "Could not locate URL in $url_file" >&2
        cat "$url_file"
        exit
    fi
else
    # Fallback to default url template
    echo "Could not find $url_file, best guess for url" >&2
    conf_view_url=${conf_dav_url%*/plugins/servlet/confluence/default}/display/$(urlencode "$wiki_root")/$(urlencode "$confluence_directory_name")
fi

# Show the Published URL
echo "$conf_view_url"
