# source this file at top of a cgi
set -ue 
trap 'echo $0: line $LINENO: exit status $? >&2' ERR
[[ ${QUERY_STRING:-} ]] && { OFS=$IFS; IFS='&'; set -- $QUERY_STRING; IFS=$OFS; }                                                                                                                                                        
