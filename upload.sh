#!/bin/bash
set -e

printf "\n=====================================================================================\n"
printf "KOBITON APP UPLOAD ACTION"
printf "\n=====================================================================================\n\n"

hash jq 2>/dev/null || {
    echo >&2 "jq required, but it's not installed."
    exit 1
}

json_field() {
    jq -er ".$1" "$2" || {
        echo >&2 "No $1 in $2:"
        cat >&2 "$2"
        exit 1
    }
}

BASICAUTH=$(echo -n "$KOBI_USERNAME":"$KOBI_API_KEY" | base64)

if [ -z "$UPLOAD_APP_ID" ]; then
    JSON=("{\"filename\":\"${APP_NAME}.${APP_SUFFIX}\"}")
else
    JSON=("{\"filename\":\"${APP_NAME}.${APP_SUFFIX}\",\"appId\":$UPLOAD_APP_ID}")
fi

curl --silent -X POST https://api.kobiton.com/v1/apps/uploadUrl \
    -H "Authorization: Basic $BASICAUTH" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    -d "${JSON[@]}" \
    -o ".tmp.upload-url-response.json"

cat ".tmp.upload-url-response.json"

UPLOAD_URL=$(json_field url ".tmp.upload-url-response.json")
KAPPPATH=$(json_field appPath ".tmp.upload-url-response.json")

echo "Uploading: ${APP_NAME} (${APP_PATH})"
echo "URL: ${UPLOAD_URL}"

curl --progress-bar -T "${APP_PATH}" \
    -H "Content-Type: application/octet-stream" \
    -H "x-amz-tagging: unsaved=true" \
    -X PUT "${UPLOAD_URL}"
#--verbose

echo "Processing: ${KAPPPATH}"

JSON=("{\"filename\":\"${APP_NAME}.${APP_SUFFIX}\",\"appPath\":\"${KAPPPATH}\"}")
curl -X POST https://api.kobiton.com/v1/apps \
    -H "Authorization: Basic $BASICAUTH" \
    -H 'Content-Type: application/json' \
    -d "${JSON[@]}" \
    -o ".tmp.upload-app-response.json"

echo "Response:"
cat ".tmp.upload-app-response.json"

APP_VERSION_ID=$(json_field versionId ".tmp.upload-app-response.json")

# Kobiton need some times to update the appId for new appVersion
sleep 30

curl -X GET https://api.kobiton.com/v1/app/versions/"$APP_VERSION_ID" \
    -H "Authorization: Basic $BASICAUTH" \
    -H "Accept: application/json" \
    -o ".tmp.get-appversion-response.json"

UPLOAD_APP_ID=$(json_field appId ".tmp.get-appversion-response.json")

curl -X PUT https://api.kobiton.com/v1/apps/"$UPLOAD_APP_ID"/"$APP_ACCESS" \
    -H "Authorization: Basic $BASICAUTH"

echo "Uploaded app to kobiton repo with appId: ${UPLOAD_APP_ID} and versionId: ${APP_VERSION_ID}"
echo "Done"
