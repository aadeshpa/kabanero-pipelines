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
if [[ ( "$IMAGE_REGISTRY_PUBLISH" == true ) ]]; then
   echo "We will publish utils image"
   echo "[INFO] Building image using $image_build_option"
   if [ ! -z "$TRAVIS_TAG" ] ; then
      echo "Travis_tag variable is not empty TRAVIS_TAG=$TRAVIS_TAG"
   else
       echo "[INFO] This travis build is not for a tagged TRAVIS_TAG and its empty, hence skipping the build and publish of the image DOCKER_USERNAME/IMAGE_NAME"
   fi
   
   if [[ ( ! -z "$image_build_option" ) && ( "$image_build_option" == "docker" ) ]]; then
      echo "Building the image using image_build_option = $image_build_option"
   elif [[ ( ! -z "$image_build_option" ) && ( "$image_build_option" == "buildah" ) ]]; then
        echo "Building the image using image_build_option=$image_build_option"
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
   echo "We are not building the utils image"
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
