#!/bin/bash

# Global variables
INPUTS_DIR_NAME=data/input
PREPROCESSING_DIR_NAME=data/preprocessing
OUTPUT_DIR_NAME=data/output
BIN_RUN_SCRIPT="bin/run.sh"
ERROR_LOGS_DIR=error_logs
PROCESS_OUTPUT=

function executeDockerContainer {
  cd ${SANDBOX}

  CONTAINER_ID=$(docker ps | grep "${CONTAINER_REPOSITORY}:${CONTAINER_TAG}" | awk '{print $1}')

  docker exec $CONTAINER_ID bash -x $BIN_RUN_SCRIPT ${IMAGE_NEW_COLLECTION_NAME} ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$INPUTS_DIR_NAME ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$OUTPUT_DIR_NAME
}

function removeDockerContainer {
  CONTAINER_ID=$(docker ps -aqf "name=${CONTAINER_TAG}")

  echo "Removing docker container $CONTAINER_ID"
  docker rm -f $CONTAINER_ID
}

# This function do a checksum of all output files in image dir
function checkSum {
  sudo find ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$OUTPUT_DIR_NAME -type f -iname "*.nc" | while read f
  do
    CHECK_SUM=$(echo | md5sum $f | cut -c1-32)
    sudo touch $f.$CHECK_SUM.md5
  done
}

function moveTempFiles {
  echo "Moving temporary out and err files"
  sudo mv ${SANDBOX}/*out ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$OUTPUT_DIR_NAME
  sudo mv ${SANDBOX}/*err ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$OUTPUT_DIR_NAME
  PROCESS_OUTPUT=$?

  if [ $PROCESS_OUTPUT -ne 0 ]
  then
    echo "Fail while transfering out and err files to ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$OUTPUT_DIR_NAME"
  fi
}

function checkProcessOutput {
  PROCESS_OUTPUT=$?

  if [ $PROCESS_OUTPUT -ne 0 ]
  then
    echo "PROCESS_OUTPUT = $PROCESS_OUTPUT"
    if [ ! -d "${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$ERROR_LOGS_DIR" ]
    then
      sudo mkdir -p ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$ERROR_LOGS_DIR
    fi

    echo "Copying temporary out and err files to ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$ERROR_LOGS_DIR"
    sudo cp ${SANDBOX}/*out ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$ERROR_LOGS_DIR
    sudo cp ${SANDBOX}/*err ${SEBAL_MOUNT_POINT}/${IMAGE_NEW_COLLECTION_NAME}/$ERROR_LOGS_DIR
    finally
  fi
}

# This function ends the script
function finally {
  # see if this rm will be necessary
  #rm -r /tmp/Rtmp*
  echo $PROCESS_OUTPUT > ${REMOTE_COMMAND_EXIT_PATH}
  exit $PROCESS_OUTPUT
}

executeDockerContainer
checkProcessOutput
removeDockerContainer
checkProcessOutput
checkSum
checkProcessOutput
moveTempFiles
checkProcessOutput
finally
