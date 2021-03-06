#!/bin/bash
# no need to use OCI - this purely use REST
#CONFIG=${CONFIG:- ~/.oci/config}
DEFAULT_ENDPOINT="database.us-ashburn-1.oraclecloud.com"
ENDPOINT=${ENDPOINT:-"$DEFAULT_ENDPOINT"}

function die { echo "FATAL: $@" 1>&2 ; exit 2; }
function die_usage { echo "FATAL: $@" 1>&2 ; usage; }
function log { echo "INFO: $@" 1>&2 ; }

function usage
{
    echo "$@" 1>&2;
    cat <<EOF 1>&2

USAGE:
    $0 <ADB ID>

ENVIRONMENT VARIABLES:
    OCIUSEROCID - OCID of the user to get the wallet
    OCIAPIKEYFP - finger print of the the API KEY
    OKEY - the API Key
    OCITENANTOCID - OCID of the tenant
    ENDPOINT - API endpoint, default $DEFAULT_ENDPOINT

EOF
    exit 2;
}

function oci-curl {
    # setup vars
    local tenancyId="${1}";
	  local authUserId="${2}";
	  local keyFingerprint="${3}";
	  local privateKeyPath="${4}";
	  local adbId="${5}";

    local alg=rsa-sha256
    local sigVersion="1"
    local now="$(LC_ALL=C \date -u "+%a, %d %h %Y %H:%M:%S GMT")"
    local host=$ENDPOINT
    local body="./payload.json"
    # local target="/20160918/autonomousDatabases/${adbId}/generateWallet"
    local target="/20160918/autonomousDatabases/${adbId}/actions/generateWallet"
    local keyId="$tenancyId/$authUserId/$keyFingerprint"

    local curl_method="POST";
    local request_method="post";
    local content_sha256="$(openssl dgst -binary -sha256 < $body | openssl enc -e -base64)";
    # local content_sha256="$(openssl dgst -sha256 < $body | openssl enc -e -base64)";
    local content_type="application/json";
    local content_length="$(wc -c <  $body | xargs )";
    # local content_length="$(echo $content_lengthp1-1 | bc )";
    # This line will url encode all special characters in the request target except "/", "?", "=", and "&", since those characters are used
    # in the request target to indicate path and query string structure. If you need to encode any of "/", "?", "=", or "&", such as when
    # used as part of a path value or query string key or value, you will need to do that yourself in the request target you pass in.
    local escaped_target="$(echo $( rawurlencode "$target" ))"

    local request_target="(request-target): $request_method $escaped_target"
    local date_header="date: $now"
    local host_header="host: $host"
    local content_sha256_header="x-content-sha256: $content_sha256"
    local content_type_header="content-type: $content_type"
    local content_length_header="content-length: $content_length"
    local signing_string="$request_target
$date_header
$host_header"
    local headers="(request-target) date host"
    local curl_header_args
    curl_header_args=(-H "$date_header")
    local body_arg
    body_arg=()

    if [ "$curl_method" = "PUT" -o "$curl_method" = "POST" ]; then
        signing_string="$signing_string
$content_sha256_header
$content_type_header
$content_length_header"
        headers=$headers" x-content-sha256 content-type content-length"
        curl_header_args=("${curl_header_args[@]}" -H "$content_sha256_header" -H "$content_type_header" -H "$content_length_header")
        body_arg=(--data-binary @${body})
        # body_arg=(-d @${body})
    fi

    local sig=$(printf '%b' "$signing_string" | \
                openssl dgst -sha256 -sign $privateKeyPath | \
                openssl enc -e -base64 | tr -d '
')
    echo "body args: ${body_arg[@]}"
    curl -v -o ./wallet.zip "${body_arg[@]}" -X $curl_method -sS "https://${host}${escaped_target}" "${curl_header_args[@]}" \
        -H "Authorization: Signature version=\"$sigVersion\",keyId=\"$keyId\",algorithm=\"$alg\",headers=\"${headers}\",signature=\"$sig\"" \

}

# url encode all special characters except "/", "?", "=", and "&"
function rawurlencode {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] | "/" | "?" | "=" | "&" ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done

  echo "${encoded}"
}

function main {
    [[ -z "${1}" ]] && die_usage "ADB ID must be passed as first argument"
    [[ -z "${ENDPOINT}" ]] && die_usage "environment variable for ENDPOINT must be set"

#    TENANCY=<tenancy_ocid>
#    USERID=<user_id>
#    PRIVATEKEYPATH=oci_api_key.pem
#    FINGERPRINT=<fingerprint>
#    REGION=<region>
    ENDPOINT=${ENDPOINT}
    TENANCY=${OCITENANTOCID}
    USERID=${OCIUSEROCID}
    PRIVATEKEYPATH=/reward/ociapikey.pem
    FINGERPRINT=${OCIAPIKEYFP}
    REGION=${OCIREGION}
    echo "entering main"
    echo "checking environment vars"
    echo "TENANCY: ${TENANCY}"
    echo "USERID: ${USERID}"
    echo "FINGERPRINT: ${FINGERPRINT}"
    echo "ENDPOINT=${ENDPOINT}"
    oci-curl "${TENANCY}" "${USERID}" "${FINGERPRINT}" "${PRIVATEKEYPATH}" "${1}"
}
echo "entering dl.wallet.sh"
echo "checking environment vars"
echo "TENANCY: ${TENANCY}"
echo "USERID: ${USERID}"
echo "FINGERPRINT: ${FINGERPRINT}"
echo "ENDPOINT=${ENDPOINT}"

main "$@"
