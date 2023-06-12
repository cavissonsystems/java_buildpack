@echo off
REM ---------------------------------------------------------------------------------
REM
REM Name      :  uninstall.bat
REM Author    :  Prabhat Vashist
REM Purpose   :  To remove CavMonAgent from Windows Server as service.
REM
REM Modification History :
REM     07/22/10 : Prabhat Vashist - Initial Version
REM
REM ---------------------------------------------------------------------------------

for %%i in ("%~dp0..") do set "CAV_MON_HOME=%%~fi"
set CAV_MON_HOME=%CAV_MON_HOME%

REM Log file creation(Uninstall)
set LOG_FILE="%CAV_MON_HOME%"\\cmon_uninstall.log

REM Service Name
set SERVICE_NAME=CavMonAgent

REM Path for the Service
set PR_INSTALL=%CAV_MON_HOME%\sys\CavMonAgent64.exe

REM current directory
set "CURRENT_DIR=%CAV_MON_HOME%/bin" 

echo "=========================================================" >> %LOG_FILE%
echo Uninstallation Started >> %LOG_FILE%
echo Uninstalling CavMonAgent ....
echo Stoping CavMonAgent >> %LOG_FILE%
REM ********************************************Stopping Service****************************
"%PR_INSTALL%" //SS//%SERVICE_NAME%
C:\\Windows\\System32\\sc queryex %SERVICE_NAME% >>%LOG_FILE%
if %ERRORLEVEL% EQU 1060 (
    echo Service does not exist. >> %LOG_FILE%
  ) else (
    echo CavMonAgent Stopped Succesfully. >> %LOG_FILE%
	REM ********************************************Service stopped***************************
	REM ********************************************Deleting Service ***************************
	echo Removing CavMonAgent... >> %LOG_FILE%
	C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul  
	"%PR_INSTALL%" //DS//%SERVICE_NAME%
	  Rem Sleep for 2 sec, waiting for stopping CavMonAgent
        C:\\Windows\\System32\\ping 127.0.0.1 -n 2 > nul
		del "%CAV_MON_HOME%"\\bin\\CavMonCScript.exe
		del "%CAV_MON_HOME%"\\bin\\CavMonCmd.exe
		del "%CAV_MON_HOME%"\\bin\\del CavMonTaskkill.exe
	    rmdir "%CAV_MON_HOME%"\\logs /s /q
        del "%CAV_MON_HOME%"\\sys\\CavMonAgent.exe
        del "%CAV_MON_HOME%"\\sys\\CavMonAgent.ini
        del "%CAV_MON_HOME%"\\sys\\CavMonAgent64.exe
        del "%CAV_MON_HOME%"\\sys\\CavMonAgent64.ini
        echo CavMonAgent Removed Succesfully. >> %LOG_FILE%
	    echo Uninstallation of CavMonAgent is Completed. >> %LOG_FILE%
		echo Service Removed from this computer. >> %LOG_FILE%
	)

echo "=========================================================" >> %LOG_FILE%
echo Exiting service.bat ...
REM ********************************************Service Deleted***************************
cd "%CURRENT_DIR%"
exit 0
