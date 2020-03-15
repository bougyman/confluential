#!/bin/bash
# 
# This script prettifies confluence 'txt' files (Which are actually xhtml files, squashed)
# Into pretty xml files

source_file=$1
[ -f "$source_file" ] || { 
    echo "$source_file" does not exist 
    exit 1
}
just_file=${source_file%.*}
txt_file=$just_file.txt
xml_file=$just_file.xml
if [ -f "$txt_file" ]
then
    bak=${txt_file}.bak.$(date +%s)
    echo "Backing up '$txt_file' to '$bak'" >&2
    echo cp "$txt_file" "$bak"
fi
if tidy -i -w 0 -xml "$source_file" > "$xml_file" 2>/dev/null
then
    echo "Wrote $xml_file" >&2
else
    code=$?
    echo "Error writing $xml_file" >&2
    exit $code
fi

