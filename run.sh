#!/bin/bash
# ArXiv Blog Agent - 快速运行脚本

# 设置项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 创建日志目录
mkdir -p logs

# 激活虚拟环境（如果存在）
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# 解析参数
CONFIG_FILE="configs/config.yaml"
DRY_RUN=""
QUERY=""
MAX_RESULTS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        -q|--query)
            QUERY="--query $2"
            shift 2
            ;;
        -m|--max-results)
            MAX_RESULTS="--max-results $2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --config FILE      配置文件路径"
            echo "  -d, --dry-run          干运行模式"
            echo "  -q, --query TEXT       搜索关键词"
            echo "  -m, --max-results N    最大结果数"
            echo "  -h, --help             显示帮助"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 运行 Agent
echo "=========================================="
echo "ArXiv Blog Agent"
echo "=========================================="
echo "配置文件: $CONFIG_FILE"
echo "干运行模式: ${DRY_RUN:-否}"
echo "=========================================="

python src/main.py \
    --config "$CONFIG_FILE" \
    $DRY_RUN \
    $QUERY \
    $MAX_RESULTS
