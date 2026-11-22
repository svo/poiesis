#!/usr/bin/env bash

image=$1 &&
architecture=$2 &&

docker run --rm -v "$(pwd)":/working-dir -v /var/run/docker.sock:/var/run/docker.sock --entrypoint ./bin/create-image "svanosselaer/-builder:${architecture}" "${image}" "${architecture}"
