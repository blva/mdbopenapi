#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

#########################################################
# Prepare collection for Postman API
# Environment variables:
#   COLLECTION_FILE_NAME - name of the postman collection file
#   COLLECTION_TRANSFORMED_FILE_NAME - name of the transformed collection file
#   OPENAPI_FOLDER - folder where openapi file is saved
#   TMP_FOLDER - folder for temporary files during transformations
#   USE_ENVIRONMENT_AUTH - bool for if auth variables are stored at the environment or collection level
#   VERSIONS_FILE - name for the openapi versions file
#   BASE_URL - the default base url the Postman Collection will use
#########################################################

COLLECTION_FILE_NAME=${COLLECTION_FILE_NAME:-"collection.json"}
COLLECTION_TRANSFORMED_FILE_NAME=${COLLECTION_TRANSFORMED_FILE_NAME:-"collection-transformed.json"}
OPENAPI_FOLDER=${OPENAPI_FOLDER:-"../openapi"}
TMP_FOLDER=${TMP_FOLDER:-"../tmp"}
USE_ENVIRONMENT_AUTH=${USE_ENVIRONMENT_AUTH:-true}
VERSIONS_FILE=${VERSIONS_FILE:-"versions.json"}

current_api_revision=$(jq -r '.versions."2.0" | .[-1]' < "${OPENAPI_FOLDER}/${VERSIONS_FILE}")

pushd "${TMP_FOLDER}"

echo "Wrapping Collection in \"collection\" tag"
jq '{"collection": .}' "$COLLECTION_FILE_NAME" > intermediateCollectionWrapped.json

echo "Disabling query params by default"
jq '(.. | select(.request? != null).request.url.query.[].disabled) = true ' intermediateCollectionWrapped.json > intermediateCollectionDisableQueryParam.json

# This is to be removed because it is autogenerated when a new collection is created
echo "Removing _postman_id"
jq 'del(.collection.info._postman_id)' intermediateCollectionDisableQueryParam.json > intermediateCollectionNoPostmanID.json

echo "Updating name with version"
jq '.collection.info.name = "MongoDB Atlas Administration API '"${current_api_revision}"'"' intermediateCollectionNoPostmanID.json >  intermediateCollectionWithName.json

echo "Updating baseUrl"
jq '.collection.variable.[0].value = "'"${BASE_URL}"'"' intermediateCollectionWithName.json > intermediateCollectionWithBaseURL.json

if [ "$USE_ENVIRONMENT_AUTH" = "false" ]; then
  echo "Adding auth variables"
  jq '.collection.variable += [{"key": "digestAuthUsername", "value": "<string>"},
  {"key": "digestAuthPassword", "value": "<string>"},
  {"key": "realm", "value": "<string>"}]' intermediateCollectionWithBaseURL.json > "$COLLECTION_TRANSFORMED_FILE_NAME"
else
  cp intermediateCollectionWithBaseURL.json "$COLLECTION_TRANSFORMED_FILE_NAME"
fi

rm intermediateCollectionWrapped.json \
   intermediateCollectionDisableQueryParam.json \
   intermediateCollectionNoPostmanID.json \
   intermediateCollectionWithName.json \
   intermediateCollectionWithBaseURL.json

popd -0