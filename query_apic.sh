#!/usr/bin/env bash

#

__author__="Aaron Castro"
__author_email__="aaron.castro.sanchez@outlook.com"
__author_nick__="i686"
__copyright__="Aaron Castro"
__license__="MIT"

#

usage() {
  echo "[i] Usage: $0 <APIC node> [-t|-a|-e|-b|-s|-i] all|<filter> [details]"
  echo "-t Query Tenants"
  echo "-a Query Application Profile"
  echo "-e Query Endpoint Groups"
  echo "-b Query Bridge Domains"
  echo "-s Query Subnets"
  echo "-i Query Endpoints"
  tput cnorm
  exit 0
}

ctrl_c() {
  echo -e '\n[!] Aborting...'
  tput cnorm
  exit 1
}

trap ctrl_c INT

auth_apic() {
  echo "[i] Logging in $APIC..."
  read -p "Username: " LOGINNAME
  read -sp "Password: " LOGINPASSWORD

  curl -s -X POST -k https://$1/api/aaaLogin.json -d "{ \"aaaUser\" : { \"attributes\" : { \"name\" : \"$LOGINNAME\", \"pwd\" : \"$LOGINPASSWORD\" } } }" -c $COOKIE > /tmp/output

}

query_fvCEp() {
  echo "[?] Querying fvCEp like $1..."
  if [ $1 != "all" ]; then
    FILTER="?query-target-filter=wcard(fvAEPg.dn,\"$1\")"
  fi
  if [ $DETAILS == "details" ]; then
    curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvCEp.json$FILTER" | jq --raw-output ".imdata[].fvCEp | map([.dn, .ip, .encap] | join(\" \")) | @tsv" | cut -d "/" -f 2,3,4,5 | column -t -s" "
  else
    curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvCEp.json$FILTER" | jq --raw-output ".imdata[].fvCEp | map(.dn) | @tsv" | cut -d "/" -f 2,3,4,5
  fi
}

query() {
  echo "[?] Querying $1 like $2..."
  if [ $2 != "all" ]; then
    FILTER="?query-target-filter=wcard($1.dn,\"$2\")"
  fi
  curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/$1.json$FILTER" | jq --raw-output ".imdata[].$1 | map(.dn) | @tsv" | cut -d "/" -f 2,3,4,5
}

tput civis
APIC=$1
COOKIE=/tmp/cookie.txt
FILTER=""

if [ "$(find $COOKIE -mmin +59 &> /dev/null)" != "" ]; then
  auth_apic $1
else
  grep "APIC-cookie" $COOKIE &> /dev/null && echo "[i] Already authenticated..." || auth_apic $1
fi

DETAILS=${@: -1}
shift
while getopts "t:a:e:b:s:i:" option; do
  case $option in
    t) query fvTenant $OPTARG;;
    a) query fvAp $OPTARG ;;
    e) query fvAEPg $OPTARG ;;
    b) query fvBD $OPTARG ;;
    s) query fvSubnet $OPTARG ;;
    i) query_fvCEp $OPTARG ;;
    *) usage ;;
  esac
done

tput cnorm
