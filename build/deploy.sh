#! /bin/bash

### Useful constants
export SRC_DIR=${PWD}/src
export TARGET_DIR=${PWD}/target
export FACTORIO_MOD=/home/nmrp3/opt/factorio/mods

### slurp info.json into environment
export MOD_NAME=`jq -r .name $SRC_DIR/info.json`

### Update the mod in the dev factorio install
rm ${FACTORIO_MOD}/${MOD_NAME}_*.zip
cp ${TARGET_DIR}/*zip $FACTORIO_MOD/