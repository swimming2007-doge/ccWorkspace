@echo off
REM 创建 Windows 定时任务 - 每天 23:00 执行 ArXiv Blog Agent

schtasks /create /tn "ArXivBlogAgent_Daily" /tr "C:\Users\Administrator\ccWorkspace\copyClawBrowserRelay\run_daily.bat" /sc daily /st 23:00 /f

echo.
echo 定时任务已创建！
echo 任务名称: ArXivBlogAgent_Daily
echo 执行时间: 每天 23:00
echo 执行脚本: run_daily.bat
echo.
echo 查看任务: schtasks /query /tn "ArXivBlogAgent_Daily"
echo 删除任务: schtasks /delete /tn "ArXivBlogAgent_Daily" /f
echo 手动执行: schtasks /run /tn "ArXivBlogAgent_Daily"
pause
