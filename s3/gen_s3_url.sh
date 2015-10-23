#!/bin/sh
file="SEP.dmg"
bucket="local-boxen"
resource="/${bucket}/${file}"
dateValue="`date +%Y%m%d`"
ISOdateValue="`date +%Y%m%dT%H%M%SZ`"
s3Key="***********************"
s3Secret="********************"

# Build Cannonical Request
cannonicalRequest="GET
${resource}
X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=${s3Key}%2F${dateValue}%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=${ISOdateValue}&X-Amz-Expires=86400&X-Amz-SignedHeaders=host
host:${bucket}.s3.amazonaws.com

host
UNSIGNED-PAYLOAD"
echo "\nCANNONICAL REQUEST\n-----------------\n""${cannonicalRequest}"

hex_hash=$( echo -n "${cannonicalRequest}" | openssl -sha | xxd -p -c 256 )
echo "${hex_hash}"

# Build string to sign
stringToSign="AWS4-HMAC-SHA256
${ISOdateValue}
${dateValue}/us-east-1/s3/aws4_request
${hex_hash}"
echo "\nSTRING TO SIGN\n-----------------\n" "${stringToSign}"

dateKey=$( echo -n "${dateValue}" | openssl dgst -sha256 -hmac "AWS4${s3Secret}" )
dateRegionKey=$( echo -n "us-east-1" | openssl dgst -sha256 -hmac "${dateKey}" )
dateRegionServiceKey=$( echo -n "s3" | openssl dgst -sha256 -hmac "${dateRegionKey}" )
signingKey=$( echo -n "aws4_request" | openssl dgst -sha256 -hmac "${dateRegionServiceKey}" )

# Generate Signature
signature=$( echo -n "${stringToSign}" | openssl dgst -sha256 -hmac "${signingKey}" )

# Generate URL
base_url="https://s3.amazonaws.com/${resource}"
algo="?X-Amz-Algorithm=AWS4-HMAC-SHA256"
credential="&X-Amz-Credential=${s3Key}%2F${dateValue}%2Fus-east-1%2Fs3%2Faws4_request"
amz_date="&X-Amz-Date=${ISOdateValue}"
expiry="&X-Amz-Expires=86400"
signed_headers="&X-Amz-SignedHeaders=host"
amz_signature="&X-Amz-Signature=${signature}"

url="${base_url}${algo}${credential}${amz_date}${expiry}${signed_headers}${amz_signature}"

echo "\nFINAL URL\n------------------\n""${url}"
