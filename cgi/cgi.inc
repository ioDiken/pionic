# source this file at top of a cgi

# point filehandle 9 at stderr, then stderr at stdin
exec 9>&2 2>&1

# abort on command error or undefined variable
set -o pipefail -E -u
trap 'echo "$0: line $LINENO: exit status $?" >&9; exit 1' ERR

# split QUERY_STRING to command line
[[ -v QUERY_STRING ]] && { IFS='&'; set -- $QUERY_STRING; IFS=$' \t\n'; }

# unescape + and %xx... is there a better way?
o=("$@")
for ((n=0; n<${#o[@]}; n++)); do
    p=${o[$n]//+/ }
    o[n]=$(echo -e ${p//%/\\x})
done
set -- "${o[@]}"
unset n o p

# crreate die function that uses fh9
die() { echo "$*" >&9; exit 1; }

# output Content-type header if invoked via cgiserver
>>>>>>> Stashed changes
[[ -v GATEWAY_INTERFACE ]] && printf "Content-type: text/plain\n\n"
