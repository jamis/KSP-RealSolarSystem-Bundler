@echo off
set CLASSPATH=.\jars\zip4j_1.3.2.jar
start java -Xmx500m -Djsse.enableSNIExtension=false -jar .\jars\real-solar-system.jar %*
