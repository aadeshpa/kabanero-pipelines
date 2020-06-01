#!/bin/bash
set -e

echo "Running publish_utils_image.sh script"


echo "TRAVIS_TAG=$TRAVIS_TAG"
if [ ! -z "$TRAVIS_TAG" ]; then
   echo "TRAVIS_TAG=$TRAVIS_TAG found and not empty."
   cd ./pipelines/docker/kabanero-utils/
   pwd
   ls -la
   
   echo "Running Docker build"  
   docker build -t $IMAGE_NAME:$IMAGE_TAG_NAME .
   echo "docker build completed successfully."
   echo "Printing the docker images"

   echo "printing all images";
   docker images --digests;
else
       echo "It is not a tagged commit or, the TRAVIS_TAG=$TRAVIS_TAG is empty"
fi
