# Zabbix Template for SqlBackupAndFTP
This repository provides a Zabbix template to monitor SqlBackupAndFTP.
It is intended to track backup job execution and transfer status through the data exposed by SqlBackupAndFTP (e.g., logs, generated files, or exported status information).

## Requirements
- Zabbix 6.0 or newer
- SqlBackupAndFTP installed and configured
- Access method used by this template (documented below)

## Versions
It's created and tested for v12 version.

## Paths and Configuration
- Change the path of the executable in the item `[SQLBackupAndFTP] Collect Data` if needed.
- The variable `$ZABBIX_BIN_DIR` is hardcoded to the path `c:\zabbix_agent`.
  - It will create a configuration file on the first execution with the configurable path of `zabbix_sender.exe`, Zabbix configuration and sqlite.dll.

## Files needed
It request SQLite.dll.au3 and sqlite.dll downloadable from https://www.autoitscript.com/autoit3/pkgmgr/sqlite/ or from https://www.sqlite.org/download.html for only dll

## Scope
This template is intended specifically for SqlBackupAndFTP and is not a generic SQL/FTP backup monitoring template.
