@echo off
REM ArXiv Blog Agent - Daily Run Script
REM 每天23点自动执行

cd /d C:\Users\Administrator\ccWorkspace\copyClawBrowserRelay

REM 设置环境变量
set ZHIPU_API_KEY=a95e2b277ce44b64948a731e9307e377.YNf2W5ZAISlGTgwe
set WORDPRESS_ACCESS_TOKEN=NIn1IRDb#eBYwyaDU5e%%6d(5Rr9iBqxtnJ8IlwRZk!s6u57OqHWmW6XQTpsN&EAu

REM 记录日志
echo [%date% %time%] Starting ArXiv Blog Agent... >> logs\daily_run.log

REM 执行程序
python src\main.py -m 5 >> logs\daily_run.log 2>&1

echo [%date% %time%] Completed. >> logs\daily_run.log
