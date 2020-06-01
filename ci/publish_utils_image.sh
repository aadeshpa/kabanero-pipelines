#!/bin/bash
set -e

echo "Running publish_utils_image.sh script"
echo "ls -la ../pipelines/docker/kabanero-utils/"
cd ../pipelines/docker/kabanero-utils/
pwd
ls -la

echo "TRAVIS_TAG=$TRAVIS_TAG"
if [ ! -z "$TRAVIS_TAG" ]; then
   echo "TRAVIS_TAG=$TRAVIS_TAG found and not empty."
else
       echo "It is not a tagged commit or, the TRAVIS_TAG=$TRAVIS_TAG is empty"
fi
