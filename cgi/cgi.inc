# source this file at top of a cgi

die() { echo "$*" >&2; exit 1; }

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

# pionic base directory
base=$(realpath ${0%/*}/..)

# pionic programs, not in path
fbput=$base/fbput/fbput
[ -x $fbput ] || die "Require executable $fbput"

runfor=$base/runfor/runfor
[ -x $runfor ] || die "require executable $runfor"

i2cio=$base/i2cio/i2cio
[ -x $i2cio ] || die "Require executable $i2cio"

fm_transmitter=$base/FM_Transmitter_RPi3/fm_transmitter
[ -x $fm_transmitter ] || die "Require executable $fm_transmitter"

# path to media
media=$base/cgi/media

# output Content-type header if invoked via cgiserver
[[ -v GATEWAY_INTERFACE ]] && printf "Content-type: text/plain\n\n"

