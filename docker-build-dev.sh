#!/bin/bash -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_TAG="$(${SCRIPT_DIR}/get_image_tag.sh)"

echo "Executing local presto docker image build..."
docker build \
       -t quay.io/cloudservices/ubi-hadoop:latest \
       -t quay.io/cloudservices/ubi-hadoop:${IMAGE_TAG} \
       -f "${SCRIPT_DIR}/Dockerfile" \
       $@ \
       "${SCRIPT_DIR}"
