#!/bin/bash
for dep in pandoc tidywiki.sh cpublish.sh
do
    if ! which "$dep" >/dev/null
    then
        echo "This script requires '$dep' to be in your path. Install '$dep' and try again"
        exit 1
    fi
done

usage() {
    echo "$0 CONFLUENCE_XML_TXT_FILE"
    echo
    echo "Converts confluence xml file into asciidoc suitable for asciidoctor"
}

conftxt=$1
if [ -z "$conftxt" ]
then
    echo "Must pass a single filename to $0"
    exit 1
fi

if [ ! -f "$conftxt" ]
then
    echo "'$conftxt' does not exist"
    exit 2
fi

confbare=${conftxt%.*}
confxml=${confbare}.xml
confraw=${confbare}-raw.adoc
confmain=${confbare}.adoc
confhtml=${confbare}.html
confxhtml=${confbare}.xhtml

# trap 'rm -f "$confxml" "$confraw"' EXIT

# Clean up the mess of txt that Confluence stores
tidywiki.sh "$conftxt"

# Replace macros (<ac: /> namespaced blockes) with [macro blocks]
sed -e 's/<\(ri:[^>]*\)>/<pre>[\1]<\/pre>/g' \
    -e 's/<\(\/ri:[^>]*\)>/<pre>[\1]<\/pre>/g' \
    -e 's/<\(ac:[^>]*\)>/<pre>[\1]<\/pre>/g' \
    -e 's/<\(\/ac:[^>]*\)>/<pre>[\1]<\/pre>/g' "$confxml" | pandoc -f html --atx-headers -t asciidoc > "$confraw"

# Replace [macro blocks] with passthrough blocks of <ac:macros />, so asciidoctor does not parse/modify them
sed -e 's/\[\(ac:[^]]*\)\]/<\1>/g' -e 's/\[\(\/ac:[^]]*\)\]/<\1>/g' \
    -e 's/\[\(ri:[^]]*\)\]/<\1>/g' -e 's/\[\(\/ri:[^]]*\)\]/<\1>/g' "$confraw"|awk '
    /^....$/ && in_macro==0 {
        in_macro=1
        next
    }

    /^....$/ && in_macro==1 {
        in_macro=0
        if(line) {
            printf("%s","+++"line"+++")
            line=""
        } else if(content) {
            print "...."
            print content
            print "...."
            content=""
        }
        next
    }

    in_macro==1 && /^<\/?(ac|ri)/{
        line=$0
        next
    }

    in_macro==1 && /^$/ { next }

    in_macro==1 {
        content = content"\n"$1
        next
    }

    { print $0 }' | awk '
        /<(ac|ri)[^\/>]*>/ { print; in_macro = 1 ; next }

        /<\/(ac|ri)[^\/>]*>/ { print; in_macro = 0; next }

        in_macro == 1 && /^$/ { next }

        { print }
        
    ' > "$confmain"

if ! read -p "$confmain created, may need edits before going to xhtml5. Enter to continue, Ctrl-C to abort" -r
then
    echo "Ok, aborting at your request"
    exit
fi

${EDITOR:-vim} "$confmain"

read -p "Would you like to convert '$confmain' to '$confxhtml'? " -r yn
if [[ "$yn" =~ ^[Yy][Ee]?$|^[Yy][Ee][Ss]$ ]]
then
    # Write the confluence-formatted output using
    # adoc_to_confluence.sh from https://github.com/amdrake93/asciidoc-confluence-converter
    if which adoc_to_confluence.sh >/dev/null 2>&1
    then
        adoc_to_confluence.sh "$confmain"
    # Fallback to asciidoctor if adoc_to_confluence.sh is not found
    elif which asciidoctor >/dev/null 2>&1
    then
        echo "Could not find adoc_to_confluence.sh, using asciidoctor for conversion" >&2
        echo "For full confluence syntax support, clone https://github.com/amdrake93/asciidoc-confluence-converter and symlink adoc_to_confluence.sh in your PATH" >&2
        asciidoctor -d article -se -b xhtml5 "$confmain"
        mv "$confhtml" "$confxhtml"
    else
        echo "ERROR: Could not find an asciidoc converter to use. 'adoc_to_confluence.sh' or 'asciidoctor' must be in your PATH" >&2
        echo "For full confluence syntax support, clone https://github.com/amdrake93/asciidoc-confluence-converter and symlink adoc_to_confluence.sh in your PATH" >&2
        echo "For basic confluence support, asciidoctor can be installed with 'gem install asciidoctor'" >&2
        exit 2
    fi

    read -p "$confhtml written. Would you like to publish it now? " -r yn
    if [[ "$yn" =~ ^[Yy][Ee]?$|^[Yy][Ee][Ss]$ ]]
    then
        cpublish.sh "$confxhtml"
    fi
fi
