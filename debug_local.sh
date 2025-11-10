#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

cd ./workspace

docker rmi redis-operator:local || true
docker build --no-cache --tag redis-operator:local .
k3d image import redis-operator:local -c cn-data-plane

kubectl patch deployment -n cn-data-plane-system redis-operator --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/imagePullPolicy", "value":"IfNotPresent"}]'
kubectl set image --namespace cn-data-plane-system deployment/redis-operator redis-operator=redis-operator:local
kubectl set env --namespace cn-data-plane-system deployment/redis-operator OPERATOR_IMAGE=redis-operator:local
