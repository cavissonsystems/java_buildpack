@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name      :  install.bat
REM Author    :  Prabhat Vashist
REM Purpose   :  To install Create Server on Windows Server as service.
REM
REM Modification History :
REM     05/07/10 : Prabhat Vashist - Initial Version
REM
REM ---------------------------------------------------------------------------------

for %%i in ("%~dp0..") do set "CAV_MON_HOME=%%~fi"
REM Log file creation(Install)
set LOG_FILE="%CAV_MON_HOME%\cmon_installation_debug.log"

REM Read the command line args and set port if valid port is given
set cmonPort=%1
set account=%2
set pwd=%3


set cmonPort=%cmonPort:-P:=% 
set account=%account:-a:=%
set pwd=%pwd:-p:=%

IF "%cmonPort%" equ " " (
	set cmonPort=7891
)

echo %cmonPort% >> %LOG_FILE%
set cmonPort=-p;%cmonPort%;

echo cmonPort=%cmonPort% >> %LOG_FILE%
echo account=%account% >> %LOG_FILE%
echo pwd=%pwd% >> %LOG_FILE%

set CAV_MON_HOME=%CAV_MON_HOME%

REM Name of the Service
set SERVICE_NAME=CavMonAgent

REM Path for the Service
set PR_INSTALL=%CAV_MON_HOME%\sys\CavMonAgent64.exe
set PR_DESCRIPTION="Cavisson Monitoring Agent"
 
REM Service log configuration
set PR_LOGPREFIX=%SERVICE_NAME%
set PR_LOGPATH=%CAV_MON_HOME%\logs\
set PR_STDOUTPUT=%CAV_MON_HOME%\stdout.txt
set PR_STDERROR=%CAV_MON_HOME%\stderr.txt
set PR_LOGLEVEL=Debug
 
REM Path to java installation
REM Set the server jvm from JAVA_HOME

set PR_JVM=%JAVA_HOME%\jre\bin\server\jvm.dll

if Not exist "%PR_JVM%" ( 
  REM Check for JRockit JVM
  set PR_JVM=%JAVA_HOME%\jre\bin\jrockit\jvm.dll
   
  if Not exist "%PR_JVM%" (
    set PR_JVM=auto
  )
)

set PR_CLASSPATH=.\..\lib\*;.\..\bin\CavMonAgent.jar;%JAVA_HOME%\lib\tools.jar;
 
REM Startup configuration
set PR_STARTUP=auto
set PR_STARTMODE=jvm
set PR_STARTCLASS=com.cavisson.monitoring.agent.CavMonAgent
set PR_STARTMETHOD=main

REM Pass any Arguments separated with semicolon
set PR_STARTPARAMS=%cmonPort%

echo PR_STARTPARAMS=%PR_STARTPARAMS% >> %LOG_FILE%

REM Shutdown configuration
set PR_STOPMODE=jvm
set PR_STOPCLASS=java.lang.System

REM com.cavisson.monitoring.agent.CavMonAgent
set PR_STOPMETHOD=exit

REM stopCavMonAgent
set PR_STOPTIMEOUT=120
 
REM JVM configuration
set PR_JVMMS=256
set PR_JVMMX=1024
set PR_JVMSS=4000
 
REM JVM options
REM set prunsrv_port=8080
REM set prunsrv_server=localhost
REM set PR_JVMOPTIONS=-Dprunsrv.port=%prunsrv_port%;-Dprunsrv.server=%prunsrv_server%
 
REM Setting Current Batch File, which would invoke CavMonAgent Installer
set "SELF=%CAV_MON_HOME%/bin/install.bat"
REM current directory
set PR_STARTPATH=%CAV_MON_HOME%/bin

REM Following Fields are used to run CMON with  specific account
set PR_SERVICEUSER=%account%
set PR_SERVICEPASSWORD=%pwd%

echo User is %PR_SERVICEUSER% and password is %PR_SERVICEPASSWORD% >> %LOG_FILE%

REM ******************UNINSTALL SECTION******************************** 
REM Before install, first need to stop CavMonAgent and delete as service
"%PR_INSTALL%" //SS//%SERVICE_NAME%
Rem Sleep for 2 sec, waiting for stopping CavMonAgent
C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul
C:\\Windows\\System32\\sc queryex %SERVICE_NAME% >>%LOG_FILE%
if %ERRORLEVEL% EQU 1060 (
    echo Service does not exist. >> %LOG_FILE%
  ) else (
		echo CavMonAgent Stopped Succesfully. >> %LOG_FILE%
		REM Used to delete the service  
		"%PR_INSTALL%" //DS//%SERVICE_NAME%
		Rem Sleep for 2 sec, waiting for deleting CavMonAgent
		C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul
		echo Removing CavMonAgent... >> %LOG_FILE%
		del "%CAV_MON_HOME%"\\bin\\CavMonCScript.exe
		del "%CAV_MON_HOME%"\\bin\\CavMonCmd.exe
		del "%CAV_MON_HOME%"\\bin\\del CavMonTaskkill.exe
	    rmdir "%CAV_MON_HOME%"\\logs /s /q
	    del "%CAV_MON_HOME%"\\sys\\CavMonAgent.exe
REM	    del "%CAV_MON_HOME%"\\sys\\CavMonAgent.ini
	    del "%CAV_MON_HOME%"\\sys\\CavMonAgent64.exe
REM	    del "%CAV_MON_HOME%"\\sys\\CavMonAgent64.ini
        echo CavMonAgent Removed Succesfully. >> %LOG_FILE%
	)
	
REM del %LOG_FILE%
REM *****************UNINSTALL COMPLETED*************************************

echo "=========================================================" >> %LOG_FILE%


REM *****************Copying Started*************************************
echo "\nCopying Required files Started\n" >> %LOG_FILE%
echo "\n\nRefer cavisson\monitors\cmon_installation_debug.log for additional details\n\n" >> %LOG_FILE%

echo "Creating Directory Structure\n" >> %LOG_FILE% 
mkdir "%CAV_MON_HOME%"\\logs >> %LOG_FILE%
mkdir "%CAV_MON_HOME%"\\sys  >> %LOG_FILE%

REM echo "Coping configuration files in Directory Structure\n" >> %LOG_FILE%
REM copy "%CAV_MON_HOME%"\\thirdparty\\*.ini  "%CAV_MON_HOME%"\\sys\\ >> %LOG_FILE%
REM if not errorlevel 0 (
REM    echo "Error in Coping *.ini files in Directory Structure\n" >> %LOG_FILE%
REM    exit -1;
REM  )

copy "%CAV_MON_HOME%"\\thirdparty\\*.exe  "%CAV_MON_HOME%"\\sys\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping *.exe files in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "Coping cscript.exe in Directory Structure\n" >> %LOG_FILE% 
copy C:\\Windows\\System32\\cscript.exe  "%CAV_MON_HOME%"\\bin\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping cscript.exe in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )
echo "cscript.exe copied in Directory Structure\n" >> %LOG_FILE% 
echo "Rename cscript.exe to CavMonCScript.exe in Directory Structure\n" >> %LOG_FILE% 
rename "%CAV_MON_HOME%"\\bin\\cscript.exe CavMonCScript.exe >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in rename cscript.exe to CavMonCScript.exe, in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )
  
echo "Copying cmd.exe in Directory Structure\n" >> %LOG_FILE%
copy C:\\Windows\\System32\\cmd.exe  "%CAV_MON_HOME%"\\bin\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping cmd.exe in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )
echo "cmd.exe copied in Directory Structure\n" >> %LOG_FILE%
echo "Rename cmd.exe to CavMonCmd.exe in Directory Structure\n" >> %LOG_FILE%
rename "%CAV_MON_HOME%"\\bin\\cmd.exe CavMonCmd.exe >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in rename cscript.exe to CavMonCScript.exe, in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

echo "Coping taskkill.exe in Directory Structure\n" >> %LOG_FILE%
copy C:\\Windows\\System32\\taskkill.exe  "%CAV_MON_HOME%"\\bin\\ >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in Coping taskkill.exe in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )
echo "taskkill.exe copied in Directory Structure\n" >> %LOG_FILE%
echo "Rename taskkill.exe to CavMonTaskkill.exe in Directory Structure\n" >> %LOG_FILE%
rename "%CAV_MON_HOME%"\\bin\\taskkill.exe CavMonTaskkill.exe >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in rename taskkill.exe to CavMonTaskkill.exe, in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )

REM creating sys\cmon.properties
IF EXIST "%CAV_MON_HOME%"\\sys\\cmon.properties (
     echo "cmon.properties is already present in CAV_MON_HOME\sys" >> %LOG_FILE%
) ELSE (
echo "Creating cmon.properties in CAV_MON_HOME\sys \n" >> %LOG_FILE%
copy /b NUL "%CAV_MON_HOME%"\\sys\\cmon.properties >> %LOG_FILE%
if not errorlevel 0 (
    echo "Error in creating cmon.properties in Directory Structure\n" >> %LOG_FILE%
    exit -1;
  )
)
REM *****************Copying Finished*************************************

REM *****************Installing CavMonAgent Started*************************************
REM Procrun command to Install CavMonAgent
echo "Installing CavMonAgent\n" >> %LOG_FILE%
"%PR_INSTALL%" //IS//%SERVICE_NAME%
if not errorlevel 0 (
    echo "Installation Fails -- Cannot Install CavMonAgent\n" >> %LOG_FILE%
    exit -1;
  )
echo "Installation of CavMonAgent Complete\n" >> %LOG_FILE%
REM *****************Installing CavMonAgent Completed*************************************

REM *****************Starting CavMonAgent*************************************
echo "Start CavMonAgent\n" >> %LOG_FILE%
REM Procrun command to Start CavMonAgent
"%PR_INSTALL%" //ES//%SERVICE_NAME%
if not errorlevel 0 (
    echo "Service not Started on this computer\n" >> %LOG_FILE%
    exit -1;
  )

echo "Service Started on this computer\n" >> %LOG_FILE%
echo "\n=========================================================\n" >> %LOG_FILE%

REM pause
exit 0
