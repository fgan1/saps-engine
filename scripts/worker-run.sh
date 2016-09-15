#!/bin/bash

# Global variables
CONF_FILE=sebal.conf
BOUNDING_BOX_PATH=example/boundingbox_vertices
IMAGES_DIR_NAME=images
RESULTS_DIR_NAME=results
OUTPUT_IMAGE_DIR=${SEBAL_MOUNT_POINT}/$RESULTS_DIR_NAME/${IMAGE_NAME}
LIBRARY_PATH=/usr/local/lib/${ADDITIONAL_LIBRARY_PATH}

# User's responsability
R_EXEC_DIR=${SANDBOX}/${R_REPOSITORY_PATH}

SEBAL_DIR_PATH=
LOG4J_PATH=

# This function untare image and creates an output dir into mounted dir
function untarImageAndPrepareDirs {
  cd ${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME

  echo "Image file name is "${IMAGE_NAME}

  # untar image
  echo "Untaring image ${IMAGE_NAME}"
  cd ${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/${IMAGE_NAME}
  sudo tar -xvzf ${IMAGE_NAME}".tar.gz"

  echo "Creating image output directory"
  sudo mkdir -p $OUTPUT_IMAGE_DIR
}

# This function calls a pre process java code to prepare a station file of a given image
function preProcessImage {
  cd ${SANDBOX}/SEBAL/
  SEBAL_DIR_PATH=$(pwd)
  LOG4J_PATH=$SEBAL_DIR_PATH/log4j.properties

  #echo "Generating app snapshot"
  #mvn -e install -Dmaven.test.skip=true

  sudo java -Dlog4j.configuration=file:$LOG4J_PATH -Djava.library.path=$LIBRARY_PATH -cp target/SEBAL-0.0.1-SNAPSHOT.jar:target/lib/* org.fogbowcloud.sebal.PreProcessMain ${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/ ${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_MTL.txt" ${SEBAL_MOUNT_POINT}/$RESULTS_DIR_NAME/ 0 0 9000 9000 1 1 $SEBAL_DIR_PATH/$BOUNDING_BOX_PATH $SEBAL_DIR_PATH/$CONF_FILE ${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_MTLFmask"
  sudo chmod 777 ${SEBAL_MOUNT_POINT}/$RESULTS_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_station.csv"
  echo -e "\n" >> ${SEBAL_MOUNT_POINT}/$RESULTS_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_station.csv"
}

# This function prepare a dados.csv file and calls R script to begin image execution
function executeRScript {
  echo "Creating dados.csv for image ${IMAGE_NAME}"

  cd $R_EXEC_DIR

  echo "File images;MTL;File Station Weather;File Fmask;Path Output" > dados.csv
  echo "${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/${IMAGE_NAME};${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_MTL.txt";${SEBAL_MOUNT_POINT}/$RESULTS_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_station.csv";${SEBAL_MOUNT_POINT}/$IMAGES_DIR_NAME/${IMAGE_NAME}/${IMAGE_NAME}"_MTLFmask";$OUTPUT_IMAGE_DIR" >> dados.csv
  echo "Executing R script..."
  sudo Rscript $R_EXEC_DIR/${R_ALGORITHM_VERSION} $R_EXEC_DIR
  #R CMD BATCH "--args WD='$R_EXEC_DIR'" $R_EXEC_DIR/${R_ALGORITHM_VERSION}
  echo "Process finished!"

  echo "Renaming dados file"
  mv dados.csv dados"-${IMAGE_NAME}".csv
  sudo mv dados"-${IMAGE_NAME}".csv $OUTPUT_IMAGE_DIR
}

# This function do a checksum of all output files in image dir
function checkSum {
  sudo find ${SEBAL_MOUNT_POINT}/$RESULTS_DIR_NAME/${IMAGE_NAME} -type f -iname "*.nc" | while read f
  do
    CHECK_SUM=$(echo | md5sum $f | cut -c1-32)
    sudo touch $f.$CHECK_SUM.md5
  done
}

# This function ends the script
function finally {
  # see if this rm will be necessary
  #rm -r /tmp/Rtmp*
  PROCESS_OUTPUT=$?

  echo $PROCESS_OUTPUT > ${REMOTE_COMMAND_EXIT_PATH}
}

untarImageAndPrepareDirs
preProcessImage
executeRScript
checkSum
finally