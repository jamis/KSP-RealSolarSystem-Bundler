@echo off
java -Xmx500m -jar real-solar-system.jar %*

if ERRORLEVEL 1 (
  exit /b 1
)

java -jar real-solar-system.jar --zip
