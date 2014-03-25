#!/bin/sh

set -e

SCRIPT_PATH=${0%/*}
if [ "$0" != "$SCRIPT_PATH" ] && [ "$SCRIPT_PATH" != "" ]; then 
  cd $SCRIPT_PATH
fi

CLASSPATH=./jars/zip4j_1.3.2.jar
java -Djsse.enableSNIExtension=false -jar jars/real-solar-system.jar $*
