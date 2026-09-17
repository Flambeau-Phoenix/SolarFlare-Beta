@echo off
setlocal
cd /d "%~dp0"
python cdb_agent.py %*
