#!/bin/bash
dir=$1
shift
while IFS= read -r -d '' file
do
    [ -L "$file" ] && continue
    path=${file//Personal/Personal/~${USER}}
    confluence_path=$HOME/confluence/dav/$path
    if [ ! -f "$confluence_path" ]
    then
        echo "'$confluence_path' does not exist, skipping (You may need to create it)" >&2
        continue
    fi
    ln -vfs "$confluence_path" "$file"
done < <(find "$dir" -name "*.txt" -print0)
