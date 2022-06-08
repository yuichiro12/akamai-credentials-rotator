#!/bin/bash

set -uexo pipefail

for PARAM_PATH in "$@"; do
  HOST=$(aws ssm get-parameter --with-decryption --name $PARAM_PATH/HOST | jq -r .Parameter.Value)
  CLIENT_TOKEN=$(aws ssm get-parameter --with-decryption --name $PARAM_PATH/CLIENT_TOKEN | jq -r .Parameter.Value)
  CLIENT_SECRET=$(aws ssm get-parameter --with-decryption --name $PARAM_PATH/CLIENT_SECRET | jq -r .Parameter.Value)
  ACCESS_TOKEN=$(aws ssm get-parameter --with-decryption --name $PARAM_PATH/ACCESS_TOKEN | jq -r .Parameter.Value)
  CLIENT_ID=$(aws ssm get-parameter --with-decryption --name $PARAM_PATH/CLIENT_ID | jq -r .Parameter.Value)
  CREDENTIAL_ID=$(aws ssm get-parameter --with-decryption --name $PARAM_PATH/CREDENTIAL_ID | jq -r .Parameter.Value)

  echo "[default]
host = $HOST
client_token = $CLIENT_TOKEN
client_secret = $CLIENT_SECRET
access_token = $ACCESS_TOKEN
" > /root/.edgerc

  # alpineなのでbusybox dateの書式に従う
  # 1日後にexpireするよう設定
  TIMESTAMP=$(date -u -d @"$((`date +%s`+3600*24))" "+%FT%T.000Z")

  # Credentialsのrotate
  # httpieのedgegrid拡張については akamai/httpie-edgegrid のドキュメントを参照:
  # https://github.com/akamai/httpie-edgegrid
  http --auth-type edgegrid -a default: PUT :/identity-management/v2/api-clients/$CLIENT_ID/credentials/$CREDENTIAL_ID status=ACTIVE expiresOn=$TIMESTAMP
  http --body --auth-type edgegrid -a default: POST :/identity-management/v2/api-clients/$CLIENT_ID/credentials > /tmp/response.json

  # Parameter Storeを更新
  NEW_CLIENT_TOKEN=$(jq -r .clientToken < /tmp/response.json)
  NEW_CLIENT_SECRET=$(jq -r .clientSecret < /tmp/response.json)
  NEW_CREDENTIAL_ID=$(jq -r .credentialId < /tmp/response.json)
  aws ssm put-parameter --type SecureString --name $PARAM_PATH/CLIENT_TOKEN --value $NEW_CLIENT_TOKEN --overwrite
  aws ssm put-parameter --type SecureString --name $PARAM_PATH/CLIENT_SECRET --value $NEW_CLIENT_SECRET --overwrite
  aws ssm put-parameter --type SecureString --name $PARAM_PATH/CREDENTIAL_ID --value $NEW_CREDENTIAL_ID --overwrite

  # 期限切れのtokenを削除する
  expiredCredentialIds=$(http --body --auth-type edgegrid -a default: :/identity-management/v2/api-clients/$CLIENT_ID/credentials |
    jq -r '.[] | select(.status != "DELETED") | select(.expiresOn | strptime("%Y-%m-%dT%H:%M:%S.000Z") | mktime < (now)) | .credentialId')
  for v in $expiredCredentialIds; do
    http --auth-type edgegrid -a default: POST :/identity-management/v2/api-clients/$CLIENT_ID/credentials/$v/deactivate
    http --auth-type edgegrid -a default: DELETE :/identity-management/v2/api-clients/$CLIENT_ID/credentials/$v
  done
done
