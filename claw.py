#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
copyClawBrowserRelay 启动脚本
可从任意路径调用
"""

import os
import sys
import subprocess
from pathlib import Path

# 项目路径 - 根据实际安装位置修改
PROJECT_DIR = r"C:\Users\Administrator\ccWorkspace\copyClawBrowserRelay"

# 默认配置文件
DEFAULT_CONFIG = "config.yaml"


def main():
    # 切换到项目目录
    project_path = Path(PROJECT_DIR)
    if not project_path.exists():
        print(f"Error: Project directory not found: {PROJECT_DIR}")
        print("Please modify PROJECT_DIR variable in this script")
        sys.exit(1)

    os.chdir(project_path)

    # 构建命令
    cmd = [sys.executable, "src/main.py"]

    # 解析参数
    args = sys.argv[1:]

    # 如果没有参数，显示帮助
    if not args or args[0] in ["-h", "--help"]:
        print("copyClawBrowserRelay Launcher")
        print()
        print("Usage:")
        print("  claw                    # Dry run mode (test)")
        print("  claw run                # Actual publish")
        print("  claw --show-config      # Show config")
        print("  claw -q \"your query\"    # Custom search")
        print("  claw -- --help          # Show all options")
        print()
        print("Project path:", PROJECT_DIR)
        return

    # 快捷命令
    if args[0] == "run":
        # 实际发布模式
        cmd.extend(["-c", DEFAULT_CONFIG])
    elif args[0] == "test":
        # 测试模式
        cmd.extend(["--dry-run", "-v"])
    elif args[0] == "config":
        # 显示配置
        cmd.extend(["--show-config", "-c", DEFAULT_CONFIG])
    elif args[0] == "--":
        # 透传所有参数
        cmd.extend(args[1:])
    else:
        # 默认干运行模式，透传参数
        if "--dry-run" not in args and "-d" not in args:
            cmd.append("--dry-run")
        cmd.extend(args)

    # 执行
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Execution failed: {e}")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print("\nCancelled")
        sys.exit(0)


if __name__ == "__main__":
    main()
