#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR

NAME=$(basename $(pwd))
JAR_NAME=target/${NAME}.jar

mvn clean install > /dev/null
rm out gc.log *.jfr > /dev/null || true

java -Xms64m -Xmx64m\
  -Xlog:gc:gc.log\
  -XX:+FlightRecorder -XX:StartFlightRecording=filename=${NAME}.jfr\
  -jar "$JAR_NAME" $1
