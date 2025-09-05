#!/usr/bin/env bash
# file: /app/s3_copy_folder.sh
set -euo pipefail

: "${S3_SOURCE:?Set S3_SOURCE like s3://bucket/prefix/}"
: "${DEST_DIR:=/mnt/efs/target}"   # default to EFS mount
: "${SYNC:=false}"                 # set to "true" to use `aws s3 sync`

echo "Starting copy: ${S3_SOURCE} -> ${DEST_DIR}"
mkdir -p "${DEST_DIR}"

if [[ "${SYNC}" == "true" ]]; then
  aws s3 sync "${S3_SOURCE}" "${DEST_DIR}"
else
  aws s3 cp "${S3_SOURCE}" "${DEST_DIR}" --recursive
fi

echo "✅ Copy completed."
