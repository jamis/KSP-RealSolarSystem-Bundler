@echo off
set CLASSPATH=.\jars\zip4j_1.3.2.jar
java -Xmx500m -jar .\jars\real-solar-system.jar %*

if ERRORLEVEL 1 (
  exit /b 1
)

java -jar .\jars\real-solar-system.jar --zip
