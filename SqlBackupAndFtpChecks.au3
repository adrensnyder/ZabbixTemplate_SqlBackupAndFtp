;###################################################################
;# Copyright (c) 2023 AdrenSnyder https://github.com/adrensnyder
;#
;# Permission is hereby granted, free of charge, to any person
;# obtaining a copy of this software and associated documentation
;# files (the "Software"), to deal in the Software without
;# restriction, including without limitation the rights to use,
;# copy, modify, merge, publish, distribute, sublicense, and/or sell
;# copies of the Software, and to permit persons to whom the
;# Software is furnished to do so, subject to the following
;# conditions:
;#
;# The above copyright notice and this permission notice shall be
;# included in all copies or substantial portions of the Software.
;#
;# DISCLAIMER:
;# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
;# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;# OTHER DEALINGS IN THE SOFTWARE.
;###################################################################

#AutoIt3Wrapper_Res_Description=SqlBackupAndFtp
#AutoIt3Wrapper_Res_Fileversion=1.0
#AutoIt3Wrapper_Res_ProductVersion=
#AutoIt3Wrapper_Res_Language=
#AutoIt3Wrapper_Res_LegalCopyright=Created by AdrenSnyder

#include <File.au3>
#include <Array.au3>
#include <Constants.au3>
#include <Date.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>
#AutoIt3Wrapper_Change2CUI=y
#RequireAdmin

#Region Errors Handler
Local $oErrorHandler = ObjEvent("AutoIt.Error", "_ErrFunc")
Func _ErrFunc($oError)
    ; Do anything here.
    ConsoleWrite("err.number is: " & @TAB & $oError.number & @CRLF & _
            "err.windescription:" & @TAB & $oError.windescription & @CRLF & _
            "err.description is: " & @TAB & $oError.description & @CRLF & _
            "err.source is: " & @TAB & $oError.source & @CRLF & _
            "err.helpfile is: " & @TAB & $oError.helpfile & @CRLF & _
            "err.helpcontext is: " & @TAB & $oError.helpcontext & @CRLF & _
            "err.lastdllerror is: " & @TAB & $oError.lastdllerror & @CRLF & _
            "err.scriptline is: " & @TAB & $oError.scriptline & @CRLF & _
            "err.retcode is: " & @TAB & $oError.retcode & @CRLF & @CRLF)
EndFunc   ;==>_ErrFunc
#EndRegion Errors Handler

; #### Quit with ESC
HotKeySet("{ESC}","Quit") ;Press ESC key to quit

Func Quit()
    Exit
EndFunc

#Region Globals
; #### Variables
Global $vDefaultConf[2]
Global $ConfString = ""
Global $vDefaultConf_Size
Global $Script_Disabled
Global $vZabbix_Conf
Global $vZabbix_Sender_Exe
Global $SQLite_Dll_path
Global $Zabbix_Items = ""
Global $JobList
Global $array_disc
Global $array_disc_tmp
Global $JobsCount = 0
Global $JobsNotScheduled = "OK"
#EndRegion Globals

#Region Consts
$ZABBIX_BIN_DIR = "c:\zabbix_agent"

$SQL_DB_PATH = "C:\ProgramData\Pranas.NET\SQLBackupAndFTP\Db"
$SQL_DB_CONTEXT = $SQL_DB_PATH & "\" & "context.db"
$SQL_DB_ROUTINES = $SQL_DB_PATH & "\" & "routines.db"
#EndRegion Consts

#Region Log
$LOG_NAME = @ScriptName & ".log"

$LOGDIR = $ZABBIX_BIN_DIR & "\log"
$LogFile = $LOGDIR & "\" & $LOG_NAME

if Not FileExists($LOGDIR) Then
	DirCreate($LOGDIR)
endif

if FileExists($LogFile) then
	FileDelete($LogFile)
endif
#EndRegion Log

#Region Json
; #### Json File
$JSON_NAME = @ScriptName & ".json"

$JSONDIR = $ZABBIX_BIN_DIR & "\data_apps"
$ZABBIX_FILE_DISCOVERY_JSON = $JSONDIR & "\" & $JSON_NAME

if Not FileExists($JSONDIR) Then
	DirCreate($JSONDIR)
endif

if FileExists($ZABBIX_FILE_DISCOVERY_JSON) then
	FileDelete($ZABBIX_FILE_DISCOVERY_JSON)
endif

; #### Data File for Zabbix
$ZABBIX_FILE_DATA = $JSONDIR & "\" & @ScriptName & ".data"

if FileExists($ZABBIX_FILE_DATA) then
	FileDelete($ZABBIX_FILE_DATA)
endif
#EndRegion Json


#EndRegion Conf
$CONF_NAME = @ScriptName & ".conf"

$CONFDIR = $ZABBIX_BIN_DIR & "\data_apps"
$vConf = $CONFDIR & "\" & $CONF_NAME

if Not FileExists($CONFDIR) Then
	DirCreate($CONFDIR)
endif

; #### Default conf
$vDefaultConf[1] = "SQLBackupAndFtp Configuration"
$ConfString = "# Zabbix_Sender.exe Position"
$ConfString &= "|" & "zabbix_sender_Var=c:\zabbix_agent\zabbix_sender.exe"
$ConfString &= "|" & ""
$ConfString &= "|" & "# Zabbix Configuration File"
$ConfString &= "|" & "zabbix_conf_Var=c:\zabbix_agent\data_apps\zabbix_agentd.win.conf"
$ConfString &= "|" & ""
$ConfString &= "|" & "# SQLite.dll Position"
$ConfString &= "|" & "SQLite_Dll_path=c:\zabbix_agent\dll\sqlite3.dll"
$ConfString &= "|" & ""
$ConfString &= "|" & "# Disable Checks"
$ConfString &= "|" & "script_disabled=0"

_ArrayAdd($vDefaultConf,$ConfString)
$vDefaultConf_Size = Ubound($vDefaultConf) - 1

; #### Load Conf
if FileExists($vConf) = false then
	Local $hFileOpen = FileOpen($vConf, $FO_APPEND)
	If $hFileOpen = -1 Then
		MsgBox($MB_SYSTEMMODAL, "", "Configuration file cannot be opened", 10)
	EndIf

	for $i = 1 to $vDefaultConf_Size step 1
		FileWriteLine($hFileOpen,$vDefaultConf[$i])
	Next

	FileClose($hFileOpen)

	logmsg($LogFile,"New configuration file created",true,true)
endif

For $i = 1 to _FileCountLines($vConf)
	$line = FileReadLine($vConf, $i)
	;msgbox (0,'','the line ' & $i & ' is ' & $line)
	$vResult = StringSplit($line,"=")
	;msgbox (0,'','the line ' & $i & ' is ' & $vResult)
    if $vResult[0] > 1 then
		Select
			Case StringInStr($vResult[1],"zabbix_conf_Var")
				$vZabbix_Conf = $vResult[2]
			Case StringInStr($vResult[1],"zabbix_sender_Var")
				$vZabbix_Sender_Exe = $vResult[2]
			Case StringInStr($vResult[1],"SQLite_Dll_path")
				$SQLite_Dll_path = $vResult[2]
			Case StringInStr($vResult[1],"script_disabled")
				$Script_Disabled = $vResult[2]
		endselect
	endif
Next
#EndRegion Conf

#Region Sqlite
; #### Load SQLITE
_SQLite_Startup($SQLite_Dll_path)
If @error Then
    logmsg($LogFile,"(Err:" & @error & " | File: " & $SQLite_Dll_path & ") SQLite3.dll Can't be Loaded!",true,true)
    Exit -1
EndIf
ConsoleWrite("_SQLite_LibVersion=" & _SQLite_LibVersion() & @CRLF)
#EndRegion Sqlite

#Region Main Function
if $Script_Disabled = 0 then

	Local $DB_HANDLE = ""
	Local $SQL = ""
	Local $SQL_Result = ""
	Local $aRow = ""
	Local $sMsg = ""

	$DB_HANDLE = _SQLite_Open($SQL_DB_CONTEXT)
	$SQL = "SELECT JobId,JobName,IsScheduled,ScheduleInfo,LastRunAt FROM Job"

	_SQLite_Query($DB_HANDLE,$SQL,$SQL_Result)

	$array_disc = "{" & chr(34) & "data" & chr(34) & ":["
	$array_disc_tmp = ""
	$comma = ""

	logmsg($LogFile,"",true,true)
	logmsg($LogFile,"--- Job List ",true,true)

	While _SQLite_FetchData($SQL_Result, $aRow) = $SQLITE_OK
		local $job_id = ""
		local $job_name = ""
		local $job_isscheduled = ""
		local $job_scheduleinfo = ""
		local $job_time_arr = ""
		local $job_time = ""
		local $job_time_daysdiff = 0
		local $job_weekendsearch = ""
		local $job_issuccess = 0 ;1 is good
		local $job_backupstatus = 0 ;1 is good
		local $job_size = 0
		local $job_backuptype = ""
		local $job_issuccess_prev = 0 ;1 is good
		local $job_backupstatus_prev = 0 ;1 is good

		$JobsCount += 1

		$job_id = $aRow[0]

		$job_name = $aRow[1]

		$job_isscheduled = $aRow[2]

		if $job_isscheduled = 0 then
			if $JobsNotScheduled = "OK" Then
				$JobsNotScheduled = $job_name
			Else
				$JobsNotScheduled &= @CRLF & $job_name
			endif
			ContinueLoop
		EndIf

		$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.IsScheduled[" & $job_name & "]",$job_isscheduled)

		$job_scheduleinfo = $aRow[3]

		$job_time_arr = StringRegExp($aRow[4],"(.*?)(?=\.)",1)
		if (IsArray($job_time_arr)) then
			$job_time = StringReplace($job_time_arr[0],"-","/")
			$job_time_daysdiff = _DateDiff("D",_NowTime,$job_time)


			if (_DateDayOfWeek(@WDAY) = "Saturday" or _DateDayOfWeek(@WDAY) = "Sunday") then
				$job_weekendsearch = StringRegExp($job_scheduleinfo,"Saturday|Sunday")

				if (not IsArray($job_weekendsearch)) then
					$job_time_daysdiff -= 2
				elseif $job_weekendsearch[0] = 1 then
					$job_time_daysdiff -= 1
				endif
			endif

			$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.LastRunAt[" & $job_name & "]",$job_time)
			$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.LastRun.DaysDiff[" & $job_name & "]",$job_time_daysdiff)
		endif

		Local $aRow_Routines= ""
		Local $sMsg_Routines = ""
		Local $SQL_Routines = ""
		Local $SQL_Result_Routines = ""

		$DB_HANDLE_Routines = _SQLite_Open($SQL_DB_ROUTINES)
		$SQL_Routines = "SELECT BackupType,IsSuccess,Size,BackupStatus FROM Backup WHERE JobId = " & $job_id & " ORDER BY Id DESC LIMIT 2"

		_SQLite_Query($DB_HANDLE_Routines,$SQL_Routines,$SQL_Result_Routines)
		$Row_Count = 0
		While _SQLite_FetchData($SQL_Result_Routines, $aRow_Routines) = $SQLITE_OK
			$Row_Count += 1

			; Send last status
			if $Row_Count = 1 then
				$job_backuptype = $aRow_Routines[0]
				$job_issuccess = $aRow_Routines[1]
				$job_size = $aRow_Routines[2]
				$job_backupstatus = $aRow_Routines[3]

				If $job_backupstatus = "" then
					$job_backupstatus = "-1"
				EndIf

				; Send last info to zabbix
				$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.BackupStatus[" & $job_name & "]",$job_backupstatus)
				$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.IsSuccess[" & $job_name & "]",$job_issuccess)
				$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.Size[" & $job_name & "]",$job_size)
				$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.BackupType[" & $job_name & "]",$job_backuptype)
			endif

			; Send prev status
			if $Row_Count = 2 then
				$job_backupstatus_prev = $aRow_Routines[3]
				$job_issuccess_prev = $aRow_Routines[1]
			endif

		Wend

		; If only one job copy to prev
		if $Row_Count = 1 then
			$job_backupstatus_prev = $job_backupstatus
			$job_issuccess_prev = $job_issuccess
		EndIf

		; Send prev info to zabbix
		$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.BackupStatusPrev[" & $job_name & "]",$job_backupstatus_prev)
		$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.IsSuccessPrev[" & $job_name & "]",$job_issuccess_prev)

		_SQlite_Close($SQL_DB_ROUTINES)

		$array_disc_tmp &= $comma & "{" & chr(34) & "{#SBAFJOB}" & chr(34) & ":" & chr(34) & $job_name & "" & chr(34) & "}"
		$comma = ","

		logmsg($LogFile,"JobId: " & $job_id,true,true)
		logmsg($LogFile,"JobName: " & $job_name,true,true)
		logmsg($LogFile,"JobIsScheduled: " & $job_isscheduled,true,true)
		logmsg($LogFile,"JobScheduleInfo: " & $job_scheduleinfo,true,true)
		logmsg($LogFile,"JobDayDiff: " & $job_time_daysdiff,true,true)
		logmsg($LogFile,"JobBackupType: " & $job_backuptype,true,true)
		logmsg($LogFile,"JobIsSuccess: " & $job_issuccess,true,true)
		logmsg($LogFile,"JobSize: " & $job_size,true,true)
		logmsg($LogFile,"JobBackupStatus: " & $job_backupstatus,true,true)

	WEnd

	_SQlite_Close($SQL_DB_CONTEXT)

	logmsg($LogFile,"",true,true)
	logmsg($LogFile,"JobsCount: " & $JobsCount,true,true)
	logmsg($LogFile,"",true,true)

	$array_disc &= $array_disc_tmp & "]}"

	; Send discovery data to Zabbix
	logmsg($LogFile,"Zabbix - Discovery",false,true)
	FileWrite($ZABBIX_FILE_DISCOVERY_JSON, " - backup.db.sqlbackupandftp.discovery " & $array_disc)
	$ZabbixSend = $vZabbix_Sender_Exe & " -vv -c " & $vZabbix_Conf & " -i " & $ZABBIX_FILE_DISCOVERY_JSON
	RunWait($ZabbixSend,$ZABBIX_BIN_DIR,@SW_HIDE)

endif

; Jobs Count
logmsg($LogFile,"Zabbix - Jobs Count",false,true)
$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.jobs.count",$JobsCount)

; Jobs Not Scheduled
logmsg($LogFile,"Zabbix - Jobs Not Scheduled",false,true)
$ZabbixSend = $vZabbix_Sender_Exe & " -vv -c " & $vZabbix_Conf & " -k " & "backup.db.sqlbackupandftp.jobs.notscheduled" & " -o " & chr(34) & $JobsNotScheduled & chr(34)
RunWait($ZabbixSend,$ZABBIX_BIN_DIR,@SW_HIDE)

; Send disabled data to Zabbix
logmsg($LogFile,"Zabbix - Script Disabled",false,true)
$Zabbix_Items = add_item_zabbix($Zabbix_Items,"backup.db.sqlbackupandftp.disabled",$Script_Disabled)

; Send data to Zabbix
logmsg($LogFile,"Zabbix - Data",false,true)
FileWrite($ZABBIX_FILE_DATA, $Zabbix_Items)
$ZabbixSend = $vZabbix_Sender_Exe & " -vv -c " & $vZabbix_Conf & " -i " & $ZABBIX_FILE_DATA
RunWait($ZabbixSend,$ZABBIX_BIN_DIR,@SW_HIDE)
#EndRegion Main Function

#Region Functions
; Log to file/console
func logmsg($logfile,$msg,$file = false,$console = true)
	if $file = true then
		_FileWriteLog($logfile,$msg & @CRLF)
	endif

	if $console = true Then
		ConsoleWrite($msg & @CRLF)
	endif
EndFunc

; Joint items for zabbix
func add_item_zabbix($zabbix_items,$key,$value)
	if $zabbix_items <> "" Then
		$zabbix_items &= @CRLF
	endif

	$zabbix_items = $zabbix_items & " - " & chr(34) & $key & chr(34) & " " & chr(34) & $value & chr(34)

	return $zabbix_items
endfunc
#EndRegion Functions