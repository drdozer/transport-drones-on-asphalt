#! /bin/bash
export SRC_DIR=${PWD}/src
export TARGET_DIR=${PWD}/target

### slurp info.json into environment
export MOD_NAME=`jq -r .name $SRC_DIR/info.json`
export MOD_VERSION=`jq -r .version $SRC_DIR/info.json`

export MOD_NAME_VERSION=${MOD_NAME}_${MOD_VERSION}
export MOD_TARGET=${MOD_NAME_VERSION}.zip

pushd $TARGET_DIR
# create clean target source dir and copy in source
rm -r $MOD_NAME_VERSION
mkdir $MOD_NAME_VERSION
cp -r $SRC_DIR/* $MOD_NAME_VERSION

# package into the mod zip
zip -r - $MOD_NAME_VERSION >$MOD_TARGET
popd
