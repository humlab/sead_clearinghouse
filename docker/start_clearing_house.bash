#!/bin/bash

APP_NAME=sead_clearinghouse
APP_PORT=8060
APP_BUILD=NO
DOCKER_FILE=docker/Dockerfile
APP_RESTART=NO
BUNDLE_FILE=bundle.zip

for i in "$@"
do
    case $i in
        -n=*|--name=*)
            APP_NAME="${i#*=}"
            shift
        ;;
        -p=*|--port=*)
            APP_PORT="${i#*=}"
            shift
        ;;
        -f=*|--file=*)
            DOCKER_FILE="${i#*=}"
            shift
        ;;
        --build)
            APP_BUILD=YES
            shift
        ;;
        --restart)
            APP_RESTART=YES
            shift
        ;;
        *)
        ;;
    esac
done

function stop_containers {
  echo "Stopping running containers..."
  RUNNING_IDS=(`docker ps | grep ${APP_NAME} | awk '{print $1}'` )
  for id in ${RUNNING_IDS[@]}; do
    docker stop $id
  done
}

function remove_image {
  if [[ "$(docker images -q ${APP_NAME}:latest 2> /dev/null)" != "" ]]; then
     echo "Removing previous image..."
     docker rmi -f ${APP_NAME}:latest
  fi
}

function build_image {
  if [ -f $BUNDLE_FILE ]; then
    rm -rf public docker conf
    unzip -q $BUNDLE_FILE
    mv $BUNDLE_FILE ${BUNDLE_FILE}_installed_$(date +"%Y%m%d%H%M")
  fi
  if [ ! -d public ] || [ ! -d docker ] || [ ! -d conf ]; then
    echo "Required folders not found: public docker conf"
    exit 1
  fi
  docker build -t $APP_NAME -f ${DOCKER_FILE} .
  rm -rf public docker conf
}

function run_image {
  docker run -d --rm --net=host -v /tmp -p ${APP_PORT}:${APP_PORT} $APP_NAME
}

if [ "$APP_BUILD" == "YES" ]; then

  stop_containers
  remove_image
  build_image

fi

if [ "$APP_RESTART" == "YES" ]; then

  stop_containers

fi

run_image
