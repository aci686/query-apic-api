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
  echo -n "Username: "
  read LOGINNAME
  echo -n "Password: "
  read -s LOGINPASSWORD

  curl -s -X POST -k https://$1/api/aaaLogin.json -d "{ \"aaaUser\" : { \"attributes\" : { \"name\" : \"$LOGINNAME\", \"pwd\" : \"$LOGINPASSWORD\" } } }" -c $COOKIE > /tmp/output

}

query_fvTenant() {
  echo "[?] Querying fvTenant..."
  curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvTenant.json" | jq --raw-output ".imdata[].fvTenant | map(.dn) | @tsv" | cut -d "/" -f 2 
}

query_fvAp() {
  echo "[?] Querying fvAp like $1..."
  if [ $1 != "all" ]; then
    FILTER="?query-target-filter=wcard(fvAp.dn,\"$1\")"
  fi
  curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvAp.json$FILTER" | jq --raw-output ".imdata[].fvAp | map(.dn) | @tsv" | cut -d "/" -f 2,3
}

query_fvAEPg() {
  echo "[?] Querying fvAEPg like $1..."
  if [ $1 != "all" ]; then
    FILTER="?query-target-filter=wcard(fvAEPg.dn,\"$1\")"
  fi
  curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvAEPg.json$FILTER" | jq --raw-output ".imdata[].fvAEPg | map(.dn) | @tsv" | cut -d "/" -f 2,3,4
}

query_fvBD() {
  echo "[?] Querying fvBD like $1..."
  if [ $1 != "all" ]; then
    FILTER="?query-target-filter=wcard(fvAEPg.dn,\"$1\")"
  fi
  curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvBD.json$FILTER" | jq --raw-output ".imdata[].fvBD | map(.dn) | @tsv" | cut -d "/" -f 2,3
}

query_fvSubnet() {
  echo "[?] Querying fvSubnet like $1..."
  if [ $1 != "all" ]; then
    FILTER="?query-target-filter=wcard(fvSubnet.dn,\"$1\")"
  fi
  curl -s -b $COOKIE -X GET -k "https://$APIC/api/node/class/fvSubnet.json$FILTER" | jq --raw-output ".imdata[].fvSubnet | map(.dn) | @tsv" | cut -d "/" -f 2,3,4,5
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

tput civis
APIC=$1
COOKIE=/tmp/cookie.txt
FILTER=""

if [ "$(find $COOKIE -mmin +59)" != "" ]; then
  auth_apic $1
else
  grep "APIC-cookie" $COOKIE > /dev/null && echo "[i] Already authenticated..." || auth_apic $1
fi

DETAILS=${@: -1}
shift
while getopts "ta:e:b:s:i:" option; do
  case $option in
    t) query_fvTenant ;;
    a) query_fvAp $OPTARG ;;
    e) query_fvAEPg $OPTARG ;;
    b) query_fvBD $OPTARG ;;
    s) query_fvSubnet $OPTARG ;;
    i) query_fvCEp $OPTARG ;;
    *) usage ;;
  esac
done

tput cnorm
