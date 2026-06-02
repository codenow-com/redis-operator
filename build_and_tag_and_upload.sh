#!/bin/bash

set -xeuo pipefail
IFS=$'\n\t'

WRITER_USERNAME='codenow-release-writer'
WORKSPACE_DIRECTORY='./workspace'

REPOSITORY='git@github.com:codenow-com/redis-operator'
BRANCH='custom/main'
VERSION='0.25.0-cn.0.1'
IMAGE_NAME='opstree/redis-operator'
ARCHITECTURES=('amd64' 'arm64')
REGISTRIES=('codenow-codenow-data-plane.jfrog.io' 'codenow-codenow-releases.jfrog.io')

if [ -z "${WRITER_PASSWORD:-}" ]; then
    read -p "Enter password for \"${WRITER_USERNAME}\" : " WRITER_PASSWORD
fi

# LOGIN Stage

for REGISTRY in "${REGISTRIES[@]}"; do
    echo "$WRITER_PASSWORD" | docker login --username "$WRITER_USERNAME" --password-stdin "$REGISTRY"
done

docker buildx rm multiplatform &> /dev/null || true
docker buildx create --name multiplatform --use

rm -rf "$WORKSPACE_DIRECTORY"
git clone --branch "$BRANCH" --single-branch --depth 1 "$REPOSITORY" "$WORKSPACE_DIRECTORY"
cd "$WORKSPACE_DIRECTORY"

# BUILD Stage

for REGISTRY in "${REGISTRIES[@]}"; do

    for ARCHITECTURE in "${ARCHITECTURES[@]}"; do

        docker buildx build --platform "linux/${ARCHITECTURE}" --tag "${REGISTRY}/${IMAGE_NAME}-${ARCHITECTURE}:${VERSION}" --output type=docker .

    done

done

if [ ! -z "${DRY_RUN:-}" ]; then
    exit 1
fi

# TAG Stage

git tag -a "$VERSION" -m "Custom version: ${VERSION}"
git push origin "$VERSION"

# UPLOAD Stage

for REGISTRY in "${REGISTRIES[@]}"; do

    ARGS=()
    for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
        docker push "${REGISTRY}/${IMAGE_NAME}-${ARCHITECTURE}:${VERSION}"
        ARGS+=("${REGISTRY}/${IMAGE_NAME}-${ARCHITECTURE}:${VERSION}")
    done

    docker manifest create "${REGISTRY}/${IMAGE_NAME}:${VERSION}" "${ARGS[@]}"
    docker manifest push "${REGISTRY}/${IMAGE_NAME}:${VERSION}"

done
