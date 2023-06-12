::
:: Name    : get_java_heap_dump.bat
:: Purpose : To take java heap dump
:: MOdification :

@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION
::Creating Log file
SET dir=%~n0
:: LOG FILE PATH = C:\Users\Dell\AppData\Local\Temp\get_java_heap_dump.log
SET log=%TEMP%\%dir%.log 
:: Deleting previous log file if exist
IF EXIST "%log%" break>%log%

:: Script Variables
for %%x in (%*) do (
   set /A argCount+=1
)
IF "%argCount%"=="2" GOTO :STARTWITH2ARGUMENTS
IF "%argCount%"=="4" GOTO :STARTWITH4ARGUMENTS
echo No Arguments Specified, hence quit! >> %log%
GOTO :END

:STARTWITH2ARGUMENTS
SET PID=%1
SET HEAP_DUMP_FILE=%2
GOTO :START

:STARTWITH4ARGUMENTS
SET PID=%1
SET HEAP_DUMP_FILE=%4
GOTO :START

:START
SET "JATTACH=%~dp0jattach.exe"
echo JATTACH exe path is %JATTACH% >> %log%
SET JMAP=%JAVA_HOME%\bin\jmap
echo JMAP path is %JMAP% >> %log%
SET c=1

::Check for finding Powershell arguments in PATH environment variable
echo %PATH% | %SYSTEMROOT%\System32\FIND /I "WindowsPowerShell" >nul && (
Echo Found "Powershell" arguments >>%log% ) || (
Echo Did not find Powershell arguments  >> %log%
GOTO :DIRECTEXECUTION
)

::Check for finding WMIC arguements in PATH environment variable
echo %PATH% | %SYSTEMROOT%\System32\FIND /I "Wbem;" >nul && (
Echo Found "WMIC" arguments >> %log%) || ( 
Echo Did not find WMIC arguments >>%log%
GOTO :DIRECTEXECUTION
)

::Check for finding Tasklist arguements in PATH environment variable
echo %PATH% | %SYSTEMROOT%\System32\FIND /I "System32;" >nul && (
Echo Found "Tasklist" arguments >>%log%) || (
Echo Did not find Tasklist arguments >>%log%
GOTO :DIRECTEXECUTION
)

::HEAP_SIZE
::To find Command Line Arguments of a process to calculate max heap size
FOR /F "tokens=1 delims= " %%a in ('tasklist /svc /FI "PID eq %PID%"') do SET "PROC_NAME=%%a" 
ECHO Process Name is %PROC_NAME% >> %log%
FOR /F "tokens=* USEBACKQ" %%a in (`wmic process where "name='%PROC_NAME%'" get commandline /format:list`) do (
SET commandlineargs!c!=%%a
SET /a c=!c!+1
)  
ECHO %commandlineargs3% >> %log%

for /f "tokens=1,*" %%a in ("%commandlineargs3%") do SET str=%%b
set str2=%str%
set str2=%str2:-jar =%
for %%A in (%str2%) do set last=%%A

set "str1=!str2:%last%=!"
set string=%str1%
::Finding if commandline has Xmx arguments
::If present then using those values to determine the heap size
echo %string% | %SYSTEMROOT%\System32\FIND /I "-Xmx" >nul && (
Echo.Found "-Xmx" arguments >> %log%
GOTO :FOUNDXMX
) || (
Echo.Did not find "-Xmx" arguments >> %log%
set heapsize_in_gb=0
goto commonexit
)



::Calculating Xmx
:FOUNDXMX
set str=%string:*-Xmx=-Xmx% 
set heapsize_xmx=%str:*-Xmx=% 
for /f "tokens=1 delims= " %%A in ("%heapsize_xmx%") do set heapsize_xmx=%%A
echo Heap size found in command line arguments is %heapsize_xmx% >> %log%
:::Label
::ECHO.%string% | %SYSTEMROOT%\System32\FIND /I "-Xms" && (
::Echo.Found "-Xms"
::GOTO :FOUNDXMS
::) || (
::Echo.Did not find "-Xms"
::GOTO :END
::)
:::FOUNDXMS
::set str=%string:*-Xms=-Xms% 
::set heapsize_xms=%str:*-Xms=%
::echo %heapsize_xms%
::Truncate last character of heapsize argument like 'm','g' in -Xmx512m
set test=%heapsize_xmx%
SET var=%test:~-1%
set heapsize_value=%test:~0,-1%
set heapsize_in_gb=0
if /i "%var%"=="g" GOTO :FOUNDGB
if /i "%var%"=="m" GOTO :FOUNDMB
if /i "%var%"=="k" GOTO :FOUNDKB
if /i "%var%"=="t" GOTO :FOUNDTB
if /i "%var%"=="G" GOTO :FOUNDGB
if /i "%var%"=="M" GOTO :FOUNDMB
if /i "%var%"=="K" GOTO :FOUNDKB
if /i "%var%"=="T" GOTO :FOUNDTB
echo NOT FOUND ANYTHING IN ARGUMNENT, >> %log%
echo check if heap size argument is correct. >> %log%
GOTO commonexit






:FOUNDKB
set /a heapsize_in_gb=heapsize_value/1024
set /a heapsize_in_gb=heapsize_value/1024
goto commonexit





:FOUNDMB
set /a heapsize_in_gb=heapsize_value/1024
goto commonexit





:FOUNDGB
set /a heapsize_in_gb=heapsize_value
GOTO commonexit






:FOUNDTB
set /a heapsize_in_gb=heapsize_value*1024
GOTO commonexit


:commonexit
for /F "tokens=1,3 delims=\" %%a in ("%HEAP_DUMP_FILE%") do (
   set DRIVE_NAME=%%a
)
wmic LogicalDisk Get DeviceID,FreeSpace,Size | %SYSTEMROOT%\System32\FIND /i "%DRIVE_NAME%" >test.txt
for /f "tokens=1,2,3 delims= " %%A in (test.txt) do (
   set array[1]=%%A
   set array[2]=%%B
   set array[3]=%%C
)


set DRIVE_NAME=%array[1]%
set FREE_SPACE=%array[2]%
set TOTAL_SIZE=%array[3]%
set FreeMB=%FREE_SPACE:~0,-10%
set SizeMB=%TOTAL_SIZE:~0,-10%
set /a HDPercent=100 * FreeMB / SizeMB
FOR /F %%B IN ('powershell !FREE_SPACE! / 1024') DO SET KB=%%B
set /a MB = KB/1024
set /a GB = MB/1024
Echo %DRIVE_NAME% Drive: %GB% GB Of Free Space = %HDPercent%%% Available.. >> %log%
echo Heap dump file Size required is %heapsize_in_gb% GB >> %log%
set /a available=GB-heapsize_in_gb
IF %GB% GTR %heapsize_in_gb% (
	echo File can be created as available disk space is %heapsize_in_gb% GB and required is %heapsize_in_gb% GB >> %log%
) ELSE (
    echo Insufficient disk space!
	echo Heap dump file cannot be created.
	echo File cannot be created due to insufficient disk space >> %log%
	GOTO :END
)


IF "%JAVA_HOME%" == "" (
	GOTO :LABEL_NOT_FOUND
) ELSE (
   GOTO  :LABEL_FOUND 
)

:LABEL_NOT_FOUND
ECHO JAVA_HOME not found
ECHO JAVA_HOME not found >> %log%
IF EXIST %JATTACH% (
ECHO Jattach.exe is present in the Current Directory. >> %log%
CALL :TAKE_HEAP_DUMP_USING_JATTACH
EXIT /B 0
) else (
ECHO Heap dump file cannot be created.  
ECHO Jattach.exe is present in the Current Directory. >> %log%
EXIT /B 0 
)

:LABEL_FOUND
	IF EXIST %JMAP% (
	CALL :TAKE_HEAP_DUMP_USING_JMAP
	EXIT /B 0
	) ELSE (
	CALL :TAKE_HEAP_DUMP_USING_JATTACH
	EXIT /B 0
	)
EXIT /B 0


::Take heap dump using JATTACH.EXE if JAVA_HOME is not found
:TAKE_HEAP_DUMP_USING_JATTACH
ECHO USING JATTACH FOR HEAP DUMP >> %log%
SET "COMMAND=%PID% dumpheap %HEAP_DUMP_FILE%"
ECHO %JATTACH% %COMMAND% >> %log%
powershell "%JATTACH% %COMMAND% | tee -a %log%"
EXIT /B 0


::Take heap dump using JMAP if JAVA_HOME is found
:TAKE_HEAP_DUMP_USING_JMAP 
ECHO USING JMAP FOR HEAP DUMP >> %log%
SET "COMMAND=-dump:live,format=b,file=%HEAP_DUMP_FILE% %PID%"
ECHO "%JMAP%" %COMMAND% >> %log% 
set NEW_JMAP_HOME=%JMAP: =` % 
powershell "%NEW_JMAP_HOME% %COMMAND% | tee -a %log%"
EXIT /B 0


:DIRECTEXECUTION
ECHO Did not found required paths for command execution,hence Using JATTACH for heap dump >> %log%
ECHO USING JATTACH FOR HEAP DUMP >> %log%
SET "COMMAND=%PID% dumpheap %HEAP_DUMP_FILE%"
%JATTACH% %COMMAND%
GOTO :END


:END
ENDLOCAL
