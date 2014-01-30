#!/bin/sh

set -e

java -jar real-solar-system.jar $*
java -jar real-solar-system.jar --zip
