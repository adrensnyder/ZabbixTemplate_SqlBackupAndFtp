# ZabbixTemplate_SqlBackupAndFtp
Zabbix Template created to monitor SqlBackupAndFtp. Tested on v12 version

## Versions
It's created and tested for v12 version.

## Paths and Configuration
- Change the path of the executable in the item `[SQLBackupAndFTP] Collect Data` if needed.
- The variable `$ZABBIX_BIN_DIR` is hardcoded to the path `c:\zabbix_agent`.
  - It will create a configuration file on the first execution with the configurable path of `zabbix_sender.exe`, Zabbix configuration and sqlite.dll.

## Files needed
It request SQLite.dll.au3 and sqlite.dll downloadable from https://www.autoitscript.com/autoit3/pkgmgr/sqlite/ or from https://www.sqlite.org/download.html for only dll
