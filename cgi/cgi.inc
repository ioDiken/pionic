# source this file at top of a cgi

# abort on command error or undefined variable
set -o pipefail -o errexit -o nounset
trap 'echo $0: line $LINENO: exit status $? >&2' ERR

# split QUERY_STRING to command line
[[ ${QUERY_STRING:-} ]] && { OFS=$IFS; IFS='&'; set -- $QUERY_STRING; IFS=$OFS; }

# unescape + and %xx... is there a better way?
o=("$@")
for ((n=0; n<${#o[@]}; n++)); do
    p=${o[$n]//+/ }
    o[n]=$(echo -e ${p//%/\\x}) 
done
set -- "${o[@]}"
unset n o p

# point filehandle 9 at stderr, then stderr at stdin 
exec 9>&2 2>&1

# crreate die function that uses fh9
die() { echo "$*" >&9; exit 1; }

printf "Content-type: text/plain\n\n"
