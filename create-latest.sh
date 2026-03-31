#!/usr/bin/env bash

image=$1

docker manifest rm "svanosselaer/poiesis-${image}:latest" 2>/dev/null || true

docker manifest create \
  "svanosselaer/poiesis-${image}:latest" \
  --amend "svanosselaer/poiesis-${image}:amd64" \
  --amend "svanosselaer/poiesis-${image}:arm64" &&
docker manifest push "svanosselaer/poiesis-${image}:latest"
