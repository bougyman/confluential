#!/bin/bash
for dep in pandoc asciidoctor tidywiki.sh cpublish.sh
do
    if ! which "$dep"
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

confbare=${conftxt%%.*}
confxml=${confbare}.xml
confraw=${confbare}-raw.adoc
confmain=${confbare}.adoc
confhtml=${confbare}.html

trap 'rm -f "$confxml" "$confraw"' EXIT

# Clean up the mess of txt that Confluence stores
tidywiki.sh "$conftxt"

# Replace macros (<ac: /> namespaced blockes) with [macro blocks]
sed -e 's/<\(ac:[^>]*\)>/<pre>[\1]<\/pre>/g' "$confxml" | pandoc -f html --atx-headers -t asciidoc > "$confraw"

# Replace [macro blocks] with passthrough blocks of <ac:macros />, so asciidoctor does not parse/modify them
sed -e 's/\[\(ac:[^]]*\)\]/<\1>/g' "$confraw"|awk '
    /^....$/ && in_macro==0 {
        in_macro=1
        next
    }

    /^....$/ && in_macro==1 {
        in_macro=0
        if(line) {
            print "+++"line"+++"
            print ""
            line=""
        } else if(content) {
            print "...."
            print content
            print "...."
            print ""
            content=""
        }
        next
    }

    in_macro==1 && /^<ac/{
        line=$0
        next
    }

    in_macro==1 {
        content = content"\n"$1
        next
    }

    { print }' > "$confmain"

if ! read -p "$confmain created, may need edits before going to xhtml5. Enter to continue, Ctrl-C to abort" -r
then
    echo "Ok, aborting at your request"
    exit
fi

${EDITOR:-vim} "$confmain"

read -p "Would you like to convert '$confmain' to '$confhtml'? " -r yn
if [[ "$yn" =~ ^[Yy][Ee]?$|^[Yy][Ee][Ss]$ ]]
then
    # Write the confluence-formatted output
    asciidoctor -d article -se -b xhtml5 "$confmain"

    read -p "$confhtml written. Would you like to publish it now? " -r yn
    if [[ "$yn" =~ ^[Yy][Ee]?$|^[Yy][Ee][Ss]$ ]]
    then
        cpublish.sh "$confhtml"
    fi
fi
