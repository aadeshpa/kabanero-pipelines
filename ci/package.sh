#!/bin/bash
set -e

# setup environment
. $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh

# expose an extension point for running before main 'package' processing
exec_hooks $script_dir/ext/pre_package.d

pipelines_dir=$base_dir/pipelines/incubator
eventing_pipelines_dir=$base_dir/pipelines/incubator/events
gitops_pipelines_dir=$base_dir/pipelines/experimental/gitops

# directory to store assets for test or release
assets_dir=$base_dir/ci/assets
mkdir -p $assets_dir

image_original_string=kabanero/kabanero-utils:latest
DOCKER_KABANERO_ACCOUNT=kabanero
DEFAULT_IMAGE_NAME=kabanero-utils

package() {
    local pipelines_dir=$1
    local prefix=$2
    echo -e "--- Creating pipeline artifacts for $prefix"
    # Generate a manifest.yaml file for each file in the tar.gz file
    asset_manifest=$pipelines_dir/manifest.yaml
    echo "contents:" > $asset_manifest

    # for each of the assets generate a sha256 and add it to the manifest.yaml
    assets_paths=$(find $pipelines_dir -mindepth 1 -maxdepth 1 -type f -name '*')
    local assets_names
    
          
    for asset_path in ${assets_paths}
    do
        asset_name=${asset_path#$pipelines_dir/}
        echo "Asset name: $asset_name"
        assets_names="${assets_names} ${asset_name}"
        if [ -f $asset_path ] && [ "$(basename -- $asset_path)" != "manifest.yaml" ]
        then
            sha256=$(cat $asset_path | $sha256cmd | awk '{print $1}')
            echo "- file: $asset_name" >> $asset_manifest
            echo "  sha256: $sha256" >> $asset_manifest
        fi
    done

    # build archive of tekton pipelines
    tar -czf $assets_dir/${prefix}-pipelines.tar.gz -C $pipelines_dir ${assets_names}
    tarballSHA=$(($sha256cmd $assets_dir/${prefix}-pipelines.tar.gz) | awk '{print $1}')
    echo ${tarballSHA}>> $assets_dir/${prefix}-pipelines-tar-gz-sha256
}

setup_utils_image_url(){
 echo "inside method setup for image url"
 
}

if [[ ( -z "$IMAGE_NAME" ) ]]; then
   IMAGE_NAME=$DEFAULT_IMAGE_NAME
fi
# This is for handling the build and push of utils container image, if this script is run via travis automation and 
# if DOCKER_USERNAME and DOCKER_PASSWORD are present in travis environment variables
if [ ! -z "$TRAVIS_TAG" ] && [ ! -z "$DOCKER_USERNAME" ] && [ ! -z "$DOCKER_PASSWORD" ]; then
 #Fetching the utils image digest value for the image docker.io/$DOCKER_USERNAME/$IMAGE_NAME:$TRAVIS_TAG.
 echo "[INFO] Fetching the image digest value for image docker.io/$DOCKER_USERNAME/$IMAGE_NAME:$TRAVIS_TAG"
 image_digest_value_withquote=$(docker inspect --format='{{json .RepoDigests}}' $DOCKER_USERNAME/$IMAGE_NAME:$TRAVIS_TAG | jq 'values[0]'); 
 #This is to remove double quotes at the beginning and the end of the digest value found by above command
 image_digest_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$image_digest_value_withquote");
 
 echo "[INFO] Replacing the utils container image string from 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline task yaml files";
 
 find ./ -type f -name '*.yaml' -exec sed -i 's|'"$image_original_string"'|'"$image_digest_value"'|g' {} +
 if [ $? == 0 ]; then
   echo "[INFO] Updated utils container image string from original 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline taks yaml files successfully"
 else
   echo "[ERROR] There was some error in updating the string from original 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline task yaml files."
   sleep 1
   exit 1
 fi
elif [[ ( ! -z "$TRAVIS_TAG") && (-z "$DOCKER_USERNAME") && (-z "$DOCKER_PASSWORD") ]]; then
     
     echo "[INFO] This is a build for TRAVIS_TAG=$TRAVIS_TAG, however DOCKER_USERNAME and DOCKER_PASSWORD are empty."
     echo "[INFO] Looking in the config file /ci/image_digest_mapping.config"
     echo "[INFO] sourcing the file ci/image_digest_mapping.config"
     chmod 755 ./ci/image_digest_mapping.config
     . ./ci/image_digest_mapping.config
     
     echo "[INFO] Checking the config file image_digest_mapping.config for below variable values"
     echo "[INFO] These will be used for fetching the correct utils container image based on either imagetag value or image digest value"
     echo "[INFO] utils_image_tag=$utils_image_tag"
     echo "[INFO] utils_image_url_with_digest=$utils_image_url_with_digest"
  
     setup_utils_image_url

     if [[ -z "$utils_image_url_with_digest" ]]; then
        if [[ ! -z "$utils_image_tag" ]]; then
           echo "[INFO] As per the config file 'image_digest_mapping.config' utils container image url with the tagname value found."
           echo "[INFO] Fetching the digest value from dockerhub based on the utils container image url =docker.io/$DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag"
           docker pull $DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag
           if [ $? != 0 ]; then
              echo "[ERROR] The docker image not found or some error in pulling the image ocker.io/$DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag"
              sleep 1
              exit 1
           else
              echo "[INFO] Searching for the digest value for image url=$DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag"
              image_digest_value_withquote=$(docker inspect --format='{{json .RepoDigests}}' docker.io/$DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag | jq 'values[0]');
           
              image_digest_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$image_digest_value_withquote");
              echo "[INFO] Successfully fetched image digest value for url=$DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag"
              echo "[INFO] Utils container image url with digest value=$image_digest_value"     
           fi
        else
           echo "[ERROR] The utils_image_url_with_digest variable from 'image_digest_mapping.config config' file is empty and the variable utils_image_tag is also empty, please provide atleast one and try again."
           sleep 1
           exit 1
        fi         
     else 
        image_digest_value=$utils_image_url_with_digest
        echo "[INFO] As per the config file 'image_digest_mapping.config' utils container image url with the digest value found."
        echo "[INFO] Utils container image url with digest value = $image_digest_value"
     fi
     
     echo "[INFO] Replacing the utils container image string from original 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline tasks yaml files."
     find ./ -type f -name '*.yaml' -exec sed -i 's|'"$image_original_string"'|'"$image_digest_value"'|g' {} +
     if [ $? == 0 ]; then
        echo "[INFO] Updated utils container image string from original 'image : $image_original_string' with ' image : $image_digest_value' in all the pipeline task yaml files successfully"
     else
        echo "[ERROR] There was some error in updating the utils container image string from original 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline task yaml files."
        sleep 1
        exit 1
     fi
elif [[ ( -z "$TRAVIS_BRANCH" ) && ( -z "$TRAVIS_TAG" ) && ( -z "$DOCKER_USERNAME" ) && ( -z "$DOCKER_PASSWORD" )  ]]; then
     echo "[INFO] The Travis variables TRAVIS_BRANCH and TRAVIS_TAG are empty and docker variables DOCKER_USERNAME and DOCKER_PASSWORD are also empty, package.sh is being run outside of the travis context, in the local mode"
     echo "[INFO] Looking in the config file '/ci/image_digest_mapping.config'"
     echo "[INFO] sourcing the file ci/image_digest_mapping.config"
     . image_digest_mapping.config

     echo "[INFO] Checking the config file 'ci/image_digest_mapping.config' for below variable values"
     echo "[INFO] These will be used for setting up the correct utils container image url and replace old url with this one before packaging the pipelines"
     echo "[INFO] utils_image_tag from file=$utils_image_tag"
     echo "[INFO] utils_image_url_with_digest=$utils_image_url_with_digest"
     
     if [[ ! -z "$utils_image_url_with_digest" ]]; then
        image_replacement_string=$utils_image_url_with_digest
        echo "[INFO] As per the config file 'image_digest_mapping.config' utils container image url with the digest value found."
        echo "[INFO] Utils container image url with digest value = $image_replacement_string"
     else
       if [[ ! -z "$utils_image_tag" ]]; then
          image_tag_url_value=$DOCKER_KABANERO_ACCOUNT/$IMAGE_NAME:$utils_image_tag
          echo "[INFO] As per the config file 'ci/image_digest_mapping.config' 'utils_image_url_with_digest' is empty"
          echo "[INFO] However utils container image url with the tagname value found and hence the string image in all the pipeline tasks will be updated with $image_tag_url_value"
          image_replacement_string=$image_tag_url_value
       else
          echo "[ERROR] The 'utils_image_url_with_digest' variable from 'image_digest_mapping.config config' file is empty and the variable 'utils_image_tag' is also empty, please provide atleast one and try again."
          sleep 1
          exit 1
       fi
     fi

     echo "[INFO] Replacing the utils container image string 'image : $image_original_string' with 'image : $image_replacement_string' in all the pipeline task yaml files."
     if [[ "$OSTYPE" != "darwin"* ]]; then
        find ../ -type f -name '*.yaml' -exec sed -i 's|'"$image_original_string"'|'"$image_replacement_string"'|g' {} +
     else
        find ../ -type f -name '*.yaml' -exec sed -i '' 's|'"$image_original_string"'|'"$image_replacement_string"'|g' {} +
     fi
     if [ $? == 0 ]; then
        echo "[INFO] Updated string 'image : $image_original_string' with 'image : $image_replacement_string' in all the pipeline task files successfully"
     else
        echo "[ERROR] There was some error in updating the string 'image : $image_original_string' with 'image : $image_replacement_string' in all the pipeline task yaml files."
        sleep 1
        exit 1
     fi
else
     echo "[Warning] The kabaneo-utils image was not build and pushed to dockerhub for this build, because one or more of the env variables TRAVIS_TAG=$TRAVIS_TAG or DOCKER_USERNAME=DOCKER_USERNAME or DOCKER_PASSWORD are empty "
fi
     
package $pipelines_dir "default-kabanero"

package $eventing_pipelines_dir "kabanero-events"

package $gitops_pipelines_dir "kabanero-gitops"

echo -e "--- Created pipeline artifacts"

# expose an extension point for running after main 'package' processing
exec_hooks $script_dir/ext/post_package.d

echo -e "--- Building nginx container"
nginx_arg=
echo "BUILDING: $IMAGE_REGISTRY_ORG/$INDEX_IMAGE:${INDEX_VERSION}" > ${build_dir}/image.$INDEX_IMAGE.${INDEX_VERSION}.log
if image_build ${build_dir}/image.$INDEX_IMAGE.${INDEX_VERSION}.log \
    $nginx_arg \
    -t $IMAGE_REGISTRY/$IMAGE_REGISTRY_ORG/$INDEX_IMAGE \
    -t $IMAGE_REGISTRY/$IMAGE_REGISTRY_ORG/$INDEX_IMAGE:${INDEX_VERSION} \
    -f $script_dir/nginx/Dockerfile $script_dir
then
    echo "$IMAGE_REGISTRY/$IMAGE_REGISTRY_ORG/$INDEX_IMAGE" >> $build_dir/image_list
    echo "$IMAGE_REGISTRY/$IMAGE_REGISTRY_ORG/$INDEX_IMAGE:${INDEX_VERSION}" >> $build_dir/image_list
    echo "created $IMAGE_REGISTRY_ORG/$INDEX_IMAGE:${INDEX_VERSION}"
    trace "${build_dir}/image.$INDEX_IMAGE.${INDEX_VERSION}.log"
else
    stderr "${build_dir}/image.$INDEX_IMAGE.${INDEX_VERSION}.log"
    stderr "failed building $IMAGE_REGISTRY/$IMAGE_REGISTRY_ORG/$INDEX_IMAGE:${INDEX_VERSION}"
    exit 1
fi
