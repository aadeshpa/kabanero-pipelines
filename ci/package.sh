#!/bin/bash
set -e

# setup environment
. $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/env.sh

# expose an extension point for running before main 'package' processing
exec_hooks $script_dir/ext/pre_package.d

image_build_option=$1

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

#Start
   
#setting the Utils image name as Default image name in case it is empty or not provided from env.sh
if [ -z "$UTILS_IMAGE_NAME" ]; then
   UTILS_IMAGE_NAME=$DEFAULT_IMAGE_NAME
fi
#setting up the utils image tagname as TRAVIS_TAG in case it is not empty, which is during Travis automation step.
# In other cases UTILS_IMAGE_TAG will be exported from env.sh file.
if [ ! -z "$TRAVIS_TAG" ] ; then
   echo "Travis_tag variable is not empty TRAVIS_TAG=$TRAVIS_TAG"
   UTILS_IMAGE_TAG=$TRAVIS_TAG
fi

if [[ ( "$IMAGE_REGISTRY_PUBLISH" == true ) ]]; then
   echo "We will publish utils image"
   echo "[INFO] Building image using $image_build_option" 
   
   if [[ (! -z $IMAGE_REGISTRY) && (! -z "$IMAGE_REGISTRY_USERNAME") &&  (! -z "$IMAGE_REGISTRY_PASSWORD") ]]; then
      echo "The image registry creds are present, building the image "
      if [[ ( ! -z "$UTILS_IMAGE_NAME" ) && ( ! -z "$UTILS_IMAGE_TAG" ) ]]; then
         echo "Both utils image name and utils image tag are present UTILS_IMAGE_NAME=$UTILS_IMAGE_NAME, UTILS_IMAGE_TAG=$UTILS_IMAGE_TAG"
         echo "current dir before build image"
         pwd
         cd ./pipelines/docker/kabanero-utils/
         if [[ ( ! -z "$image_build_option" ) && ( "$image_build_option" == "docker" ) ]]; then
            echo "Building the image using image_build_option = $image_build_option"
            echo "[INFO] Running docker build for image url : $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG"
            # Running actual docker build command to build the image using docker.
            #cd ./pipelines/docker/kabanero-utils/
            docker build -t $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG .       
            if [ $? == 0 ]; then
               echo "[INFO] Docker image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG was build successfully" 
               echo "[INFO] Pushing the image $IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG to $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG "
               echo "$IMAGE_REGISTRY_PASSWORD" | docker login -u $IMAGE_REGISTRY_USERNAME --password-stdin
               # Running actual docker push command to push the image  to the registry using docker.
               docker push $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG
               if [ $? == 0 ]; then
                  echo "[INFO] The docker image $IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG was successfully pushed to $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG"     
               else
                  echo "[ERROR] The docker push failed for this image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG, please check the logs"
                  sleep 1
                  exit 1
               fi    
            else
               echo "[ERROR] The docker image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG build failed, please check the logs."
               sleep 1
               exit 1
            fi
         elif [[ ( ! -z "$image_build_option" ) && ( "$image_build_option" == "buildah" ) ]]; then
              echo "Building the image using image_build_option=$image_build_option"
              
              buildah bud -t $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG .
              if [ $? == 0 ]; then
                 echo "[INFO] The buildah container image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG was build successfully"
                 
                 #Logging in via buildah login commmand to the Image_Registry
                 echo "$IMAGE_REGISTRY_PASSWORD" | buildah login -u $IMAGE_REGISTRY_USERNAME --password-stdin $IMAGE_REGISTRY
                 # Running actual buildah push command to push the image  to the registry using buildah.
                 echo "[INFO] Pushing the image $IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG to $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG "
                 buildah push $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG docker://$IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG
                 if [ $? == 0 ]; then
                    echo "[INFO] The buildah container image $IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG was successfully pushed to $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG"     
                 else
                    echo "[ERROR] The buildah container image push failed for this image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG, please check the logs"
                    sleep 1
                    exit 1
                 fi    
              else
                 echo "[ERROR] The buildah container image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG build failed, please check the logs."
                 sleep 1
                 exit 1
              fi
         elif [[ ( -z "$image_build_option" ) ]]; then
              echo "[ERROR] Input to the script is empty, valid input to this script is either 'docker' or 'buildah'"
              sleep 1;
              exit 1;
         else
              echo "[ERROR] Input to the script is not correct, valid input values to this script are either 'docker' or 'buildah'. Please fix it and try again. "
              sleep 1;
              exit 1;
         fi
      else
         echo "[ERROR] Either UTILS_IMAGE_NAME or UTILS_IMAGE_TAG or both are empty, please provide correct image name and tag name for building the utils image and try again."
         sleep 1
         exit 1
      fi
      
   else
      echo "The image registry is empty or the registry credentials are not present or both, please provide it correctly and try again."
      sleep 1
      exit 1
   fi
   

else
   echo "We are not building the utils image since IMAGE_REGISTRY_PUBLISH is not set to true "
fi

#We have to fetch the digest value for the utils image based on the image details
echo "current directory"
pwd
cd ../../../
echo "original dir after retracting"
pwd
if [[ (! -z "$IMAGE_REGISTRY") && (! -z "$IMAGE_REGISTRY_USERNAME" ) && ( ! -z "$UTILS_IMAGE_NAME" ) && ( ! -z "$UTILS_IMAGE_TAG" ) ]]; then
   echo "Fetching the image digest value for image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG"
   if [[ ( ! -z "$image_build_option" ) && ( "$image_build_option" == "docker" ) ]]; then
      echo "[INFO] Fetching the image digest value for image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG using docker inspect"
      image_digest_value_withquote=$(docker inspect --format='{{json .RepoDigests}}' $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG | jq 'values[0]'); 
      #This is to remove double quotes at the beginning and the end of the digest value found by above command
      image_digest_value=$(sed -e 's/^"//' -e 's/"$//' <<<"$image_digest_value_withquote");
      echo "[INFO] image_digest_value=$image_digest_value"

   elif [[ ( ! -z "$image_build_option" ) && ( "$image_build_option" == "buildah" ) ]]; then
      echo "[INFO] Fetching the image digest value for image $IMAGE_REGISTRY/$IMAGE_REGISTRY_USERNAME/$UTILS_IMAGE_NAME:$UTILS_IMAGE_TAG using skopeo inspect"
      echo "checking skopeo runs"
      skopeo
      image_digest_value=$( skopeo inspect docker://"$IMAGE_REGISTRY"/"$IMAGE_REGISTRY_USERNAME"/"$UTILS_IMAGE_NAME":"$UTILS_IMAGE_TAG" | jq '.Digest' )
      echo "[INFO] using skopeo image_digest_value=$image_digest_value"
      
   fi
   
   echo "[INFO] Replacing the utils container image string from 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline task yaml files";
   find ./ -type f -name '*.yaml' -exec sed -i 's|'"$image_original_string"'|'"$image_digest_value"'|g' {} +
   if [ $? == 0 ]; then
      echo "[INFO] Updated utils container image string from original 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline taks yaml files successfully"
   else
      echo "[ERROR] There was some error in updating the string from original 'image : $image_original_string' with 'image : $image_digest_value' in all the pipeline task yaml files."
      sleep 1
      exit 1
   fi
else
    echo "[ERROR] One or more of the parameters IMAGE_REGISTRY,IMAGE_REGISTRY_USERNAME, UTILS_IMAGE_NAME or UTILS_IMAGE_TAG are empty, please provide correct image registry and image details for fetching the digest value of the utils image and try again."
    echo "[ERROR] IMAGE_REGISTRY=$IMAGE_REGISTRY"
    echo "[ERROR] IMAGE_REGISTRY_USERNAME=$IMAGE_REGISTRY_USERNAME"
    echo "[ERROR] UTILS_IMAGE_NAME=$UTILS_IMAGE_NAME"
    echo "[ERROR] UTILS_IMAGE_TAG=$UTILS_IMAGE_TAG"
    sleep 1
    exit 1
fi



#End
     
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
