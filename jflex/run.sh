#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

NAME=jflex
JAR_NAME=target/${NAME}.jar

if [[ ! -f "$JAR_NAME" ]]
then
  mvn clean install
fi
rm out gc.log *.jfr

java -Xms64m -Xmx64m\
  -Xlog:gc:gc.log\
  -XX:+FlightRecorder -XX:StartFlightRecording=filename=${NAME}.jfr\
  -jar "$JAR_NAME" $1
