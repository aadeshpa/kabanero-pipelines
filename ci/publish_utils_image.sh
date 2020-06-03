#!/bin/bash
set -e

# This script will verify and run if TRAVIS_TAG is present which is the case only when a new releasecut takes place.
# Also along with the TRAVIS_TAG value, it checks if the travis settings has env variables DOCKER_USERNAME and DOCKER_PASSWORD
# set, to get access to the dockerhub repository for pushing the image if built.
# The script will build and push the image with the Travis env variables as
# docker.io/$DOCKER_USERNAME/$IMAGE_NAME:$TRAVIS_TAG


echo "TRAVIS_TAG=$TRAVIS_TAG"
#echo "Env variable from within the script publishImageStatus=${publishImageStatus}"
if [ ! -z "$TRAVIS_TAG" ] && [ ! -z "$DOCKER_USERNAME" ] && [ ! -z "$DOCKER_PASSWORD" ]; then
   cd ./pipelines/docker/kabanero-utils/
   
   #echo "Running Docker build"  
   docker build -t $IMAGE_NAME:$TRAVIS_TAG .
   if [ $? == 0 ]; then
      echo "Docker image $IMAGE_NAME:$TRAVIS_TAG was build successfully"
     
      #echo "printing all images"
      #docker images --digests
   
      echo "[INFO] Pushing the image $IMAGE_NAME:$IMAGE_TAG_NAME to docker.io/$IMAGE_NAME:$TRAVIS_TAG "
      #echo "DOCKER_USERNAME=$DOCKER_USERNAME"
      echo "$DOCKER_PASSWORD" | docker login -u $DOCKER_USERNAME --password-stdin
      docker push $IMAGE_NAME:$TRAVIS_TAG
      if [ $? == 0 ]; then
          echo "[INFO] The docker image $IMAGE_NAME:$TRAVIS_TAG was successfully pushed to docker.io/$IMAGE_NAME:$TRAVIS_TAG"
          #docker images --digests
   
          #image_digest_value_withquote=$(docker inspect --format='{{json .RepoDigests}}' $IMAGE_NAME:$TRAVIS_TAG | jq 'values[0]')
          #echo "image_digest_value_withquote=$image_digest_value_withquote"
          #image_digest_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$image_digest_value_withquote")
          #echo "image_digest_value=$image_digest_value"
          #echo "$image_digest_value"      
      else
        echo "[ERROR] The docker push failed for this image docker.io/$IMAGE_NAME:$TRAVIS_TAG, please check the logs"
        exit 1
      fi
     
   else
      echo "[ERROR] The docker image $IMAGE_NAME:$TRAVIS_TAG build failed, please check the logs."
      exit 1
   fi
else
       echo "[INFO] This travis build is not tagged with the TRAVIS_TAG=$TRAVIS_TAG, hence skipping the build and publish of the image $DOCKER_USERNAME/$IMAGE_NAME"
fi
