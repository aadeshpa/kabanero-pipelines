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
   docker build -t $IMAGE_NAME:$TRAVIS_TAG .
   if [ $? == 0 ]; then
      echo "Docker Image $IMAGE_NAME:$TRAVIS_TAG was build successfully"
     
      echo "printing all images"
      docker images --digests
   
      echo "Pushing the image $IMAGE_NAME:$IMAGE_TAG_NAME to docker.io/$DOCKER_USERNAME/$IMAGE_NAME:$TRAVIS_TAG "
      echo "DOCKER_USERNAME=$DOCKER_USERNAME"
      echo "$DOCKER_PASSWORD" | docker login -u $DOCKER_USERNAME --password-stdin
      docker push $IMAGE_NAME:$TRAVIS_TAG
      docker images --digests
   
      image_digest_value_withquote=$(docker inspect --format='{{json .RepoDigests}}' $IMAGE_NAME:$TRAVIS_TAG | jq 'values[0]')
      echo "image_digest_value_withquote=$image_digest_value_withquote"
      image_digest_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$image_digest_value_withquote")
      echo "image_digest_value=$image_digest_value"
   else
      echo "[ERROR] The container image $IMAGE_NAME:$TRAVIS_TAG build failed, please check the logs."
      exit 1
   fi

else
       echo "It is not a tagged commit or, the TRAVIS_TAG=$TRAVIS_TAG is empty"
fi
