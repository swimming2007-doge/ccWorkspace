#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
ArXiv Blog Agent - 入口文件

使用集中式配置文件 (config.yaml)

快速开始:
    python src/main.py                    # 使用默认配置
    python src/main.py --dry-run          # 干运行模式
    python src/main.py -q "transformer"   # 自定义搜索

配置文件: config.yaml（项目根目录）
"""

import os
import sys
import json
import logging

# 添加 src 目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.arxiv_blog_agent import ArXivBlogAgent, AgentResult
from utils.config_loader import load_config, get_config_dict, Config


def setup_logging(config: Config):
    """设置日志"""
    log_dir = os.path.dirname(config.logging.file)
    if log_dir and not os.path.exists(log_dir):
        os.makedirs(log_dir, exist_ok=True)

    logging.basicConfig(
        level=getattr(logging, config.logging.level, logging.INFO),
        format=config.logging.format,
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(config.logging.file, encoding="utf-8"),
        ],
    )


def parse_args():
    """解析命令行参数"""
    import argparse

    parser = argparse.ArgumentParser(
        description="ArXiv Blog Agent - Auto crawl papers and publish blog",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python src/main.py                      Use default config
  python src/main.py --dry-run            Dry run mode
  python src/main.py -q "transformer"     Custom query
  python src/main.py -c config.prod.yaml  Use custom config

Config file: config.yaml (project root)
        """,
    )

    parser.add_argument(
        "--config", "-c",
        default="config.yaml",
        help="Config file path (default: config.yaml)",
    )
    parser.add_argument(
        "--dry-run", "-d",
        action="store_true",
        help="Dry run mode (no actual publish)",
    )
    parser.add_argument(
        "--query", "-q",
        default=None,
        help="ArXiv search query",
    )
    parser.add_argument(
        "--max-results", "-m",
        type=int,
        default=None,
        help="Max results",
    )
    parser.add_argument(
        "--style", "-s",
        choices=["professional", "casual", "academic"],
        default=None,
        help="Writing style",
    )
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="Output result to JSON file",
    )
    parser.add_argument(
        "--show-config",
        action="store_true",
        help="Show current config and exit",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output",
    )

    return parser.parse_args()


def main():
    """主函数"""
    args = parse_args()

    # 加载配置
    config = load_config(args.config)

    # 设置日志级别
    if args.verbose:
        config.logging.level = "DEBUG"

    setup_logging(config)
    logger = logging.getLogger("main")

    # 显示配置
    if args.show_config:
        print("\n" + "=" * 60)
        print("Current Configuration")
        print("=" * 60)
        print(json.dumps(get_config_dict(config), indent=2, ensure_ascii=False))
        return 0

    # 命令行参数覆盖
    if args.query:
        config.arxiv.query = args.query
    if args.max_results:
        config.arxiv.max_results = args.max_results
    if args.style:
        config.content.style = args.style
    if args.dry_run:
        config.agent.dry_run = True

    # 显示启动信息
    logger.info("=" * 60)
    logger.info("ArXiv Blog Agent v1.0.0")
    logger.info("=" * 60)
    logger.info(f"Config file: {args.config}")
    logger.info(f"Query: {config.arxiv.query}")
    logger.info(f"Max results: {config.arxiv.max_results}")
    logger.info(f"Style: {config.content.style}")
    logger.info(f"Dry run: {config.agent.dry_run}")
    logger.info("=" * 60)

    # 创建并运行 Agent
    try:
        agent = ArXivBlogAgent(
            config_path=args.config,
            dry_run=args.dry_run,
        )

        # 应用命令行覆盖
        if args.query:
            agent.config.arxiv.query = args.query
        if args.max_results:
            agent.config.arxiv.max_results = args.max_results
        if args.style:
            agent.config.content.style = args.style

        result: AgentResult = agent.run()
        agent.close()

        # 输出结果
        print("\n" + "=" * 60)
        print("Result:")
        print("=" * 60)
        result_dict = result.to_dict()
        print(json.dumps(result_dict, indent=2, ensure_ascii=False))

        # 保存到文件
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                json.dump(result_dict, f, indent=2, ensure_ascii=False)
            logger.info(f"Result saved to: {args.output}")

        # 返回状态码
        if result.success:
            logger.info("SUCCESS!")
            return 0
        else:
            logger.error(f"FAILED: {result.error_message}")
            return 1

    except KeyboardInterrupt:
        logger.warning("\nUser interrupted")
        return 130
    except Exception as e:
        logger.exception("Exception")
        return 1


if __name__ == "__main__":
    sys.exit(main())
