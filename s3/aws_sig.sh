# figure out how to generate SHA256 hashes (support Linux and FreeBSD)
which sha256sum >/dev/null 2>&1 && HASH=sha256sum || HASH=sha256
# shorthand for a verbose mktemp call that works on FreeBSD
MKTEMP="mktemp -t aws-sign.XXXXXX"
 
function format_date_from_epoch() { # FreeBSD has an annoyingly non GNU-like data utility
    local epoch="$1" format="$2"
    if uname | grep -q FreeBSD; then
        date -u -jf %s $epoch "$format"
    else
        date -u -d @$epoch "$format"
    fi
}
 
function hash() { # generate a hex-encoded SHA256 hash value
  local data="$1"
  printf "%s" "$data" | $HASH | awk '{print$1}'
}
 
function hmac() {
  local keyfile="$1" data="$2"
  printf "%s" "$data" | openssl dgst -sha256 -mac HMAC -macopt hexkey:"$( hex < $keyfile )" -binary
}
 
function hex() { # pipe conversion of binary data to hexencoded byte stream
  # Note: it will mess up if you send more than 256 bytes, which is the maximum column size for xxd output
  xxd -p -c 256
}
 
function derive_signing_key() {
  local user_secret="$1" message_date="$2" aws_region="$3" aws_service="$4"
  step0="$($MKTEMP)" step1="$($MKTEMP)" step2="$($MKTEMP)" step3="$($MKTEMP)"
  printf "%s" "AWS4${user_secret}" > $step0
  hmac "$step0" "${message_date}" > $step1
  hmac "$step1" "${aws_region}" > $step2
  hmac "$step2" "${aws_service}" > $step3
  hmac "$step3" "aws4_request"
  rm -f $step0 $step1 $step2 $step3
}
 
function get_authorization_headers() { # the main implementation. Call with all the details to produce the signing headers for an HTTP request
  # Input parameters:
  # User key [required]
  # User secret [required]
  # Timestamp for the request, as an epoch time. If omitted, it will use the current time [optional]
  # AWS region this request will be sent to. If omitted, will use "us-east-1" [optional]
  # AWS service that will receive this request. [required]
  # Request address. If omitted (for example for calls without a path part), "/" is assumed to be congruent with the protocol. [optional]
  # Request query string, after sorting. May be empty for POST requests [optional]
  # POST request body. May be empty for GET requests [optional]
  local user_key="$1" user_secret="$2" timestamp="${3:-$(date +%s)}" aws_region="${4:-us-east-1}"
  local aws_service="$5" address="${6:-/}" query_string="$7" request_payload="$8"
 
  message_date="$(format_date_from_epoch $timestamp +%Y%m%d)"
  message_time="$(format_date_from_epoch $timestamp +${message_date}T%H%M%SZ)"
  aws_endpoint="${aws_service}.${aws_region}.amazonaws.com"
 
  # we always add the host header here but not in the output because we expect the HTTP client to send it automatically
  headers="$(printf "host:${aws_endpoint}\nx-amz-date:${message_time}")"
  header_list="host;x-amz-date"
 
  canonical_request="$(printf "GET\n${address}\n%s\n${headers}\n\n${header_list}\n%s" "${query_string}" "$(hash "$request_payload")")"
  canonical_request_hash="$(hash "$canonical_request")"
  credential_scope="${message_date}/${aws_region}/${aws_service}/aws4_request"
  string_to_sign="$(printf "AWS4-HMAC-SHA256\n${message_time}\n${credential_scope}\n${canonical_request_hash}")"
  signing_key="$($MKTEMP)"
  derive_signing_key "${user_secret}" "${message_date}" "${aws_region}" "${aws_service}" > $signing_key
  signature="$($MKTEMP)"
  hmac "${signing_key}" "${string_to_sign}" > $signature
  authorization_header="Authorization: AWS4-HMAC-SHA256 Credential=${user_key}/${credential_scope}, SignedHeaders=${header_list}, Signature=$( hex < $signature)"
  echo "X-Amz-Date: ${message_time}"
  echo "$authorization_header"
  rm -f $signing_key $signature
}