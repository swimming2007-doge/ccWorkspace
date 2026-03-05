#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
ArXiv Blog Agent - 入口文件

一键执行完整工作流：
1. 爬取 ArXiv 大模型训练推理相关论文
2. 生成博客格式文案
3. 发布到 WordPress.com

使用方法：
    python main.py                    # 使用默认配置运行
    python main.py --dry-run          # 干运行模式（不实际发布）
    python main.py --config prod.yaml # 使用指定配置文件
    python main.py -q "transformer"   # 自定义搜索关键词

默认配置说明：
- 搜索关键词: "large model training inference"
- 最大结果数: 10
- 发布状态: publish
- 博客平台: WordPress.com (swimming2007.wordpress.com)

注意：
- 默认使用测试令牌，实际发布需替换为真实令牌
- 支持通过配置文件或命令行参数覆盖默认配置
"""

import os
import sys
import json
import logging

# 添加 src 目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.arxiv_blog_agent import ArXivBlogAgent, AgentResult


def setup_logging():
    """设置日志"""
    log_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logs")
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)

    logging.basicConfig(
        level=logging.INFO,
        format="[%(asctime)s] %(levelname)s [%(name)s] %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(os.path.join(log_dir, "agent.log"), encoding="utf-8"),
        ],
    )


def parse_args():
    """解析命令行参数"""
    import argparse

    parser = argparse.ArgumentParser(
        description="ArXiv Blog Agent - 自动爬取论文并发布博客",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python main.py                      使用默认配置运行
  python main.py --dry-run            干运行模式（不实际发布）
  python main.py -q "transformer"     自定义搜索关键词
  python main.py -m 5                 限制最大结果数
  python main.py -c prod_config.yaml  使用指定配置文件
        """,
    )

    parser.add_argument(
        "--config", "-c",
        default="configs/config.yaml",
        help="配置文件路径 (默认: configs/config.yaml)",
    )
    parser.add_argument(
        "--dry-run", "-d",
        action="store_true",
        help="干运行模式（不实际发布到博客）",
    )
    parser.add_argument(
        "--query", "-q",
        default=None,
        help="ArXiv 搜索关键词 (默认: large model training inference)",
    )
    parser.add_argument(
        "--max-results", "-m",
        type=int,
        default=None,
        help="最大爬取结果数 (默认: 10)",
    )
    parser.add_argument(
        "--style", "-s",
        choices=["professional", "casual", "academic"],
        default=None,
        help="写作风格 (默认: professional)",
    )
    parser.add_argument(
        "--output", "-o",
        default=None,
        help="输出结果到 JSON 文件",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="显示详细日志",
    )

    return parser.parse_args()


def main():
    """主函数"""
    args = parse_args()

    # 设置日志级别
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    setup_logging()
    logger = logging.getLogger("main")

    # 构建配置覆盖
    config_override = {}
    if args.query:
        config_override["arxiv_query"] = args.query
    if args.max_results:
        config_override["arxiv_max_results"] = args.max_results
    if args.style:
        config_override["content_style"] = args.style

    # 显示启动信息
    logger.info("=" * 60)
    logger.info("ArXiv Blog Agent v1.0.0")
    logger.info("=" * 60)
    logger.info(f"配置文件: {args.config}")
    logger.info(f"干运行模式: {args.dry_run}")
    if config_override:
        logger.info(f"配置覆盖: {config_override}")
    logger.info("=" * 60)

    # 创建并运行 Agent
    try:
        agent = ArXivBlogAgent(
            config_path=args.config if os.path.exists(args.config) else None,
            config=config_override if config_override else None,
            dry_run=args.dry_run,
        )

        result: AgentResult = agent.run()
        agent.close()

        # 输出结果
        print("\n" + "=" * 60)
        print("执行结果:")
        print("=" * 60)
        result_dict = result.to_dict()
        print(json.dumps(result_dict, indent=2, ensure_ascii=False))

        # 保存到文件
        if args.output:
            with open(args.output, "w", encoding="utf-8") as f:
                json.dump(result_dict, f, indent=2, ensure_ascii=False)
            logger.info(f"结果已保存到: {args.output}")

        # 返回状态码
        if result.success:
            logger.info("✅ 执行成功!")
            return 0
        else:
            logger.error(f"❌ 执行失败: {result.error_message}")
            return 1

    except KeyboardInterrupt:
        logger.warning("\n用户中断执行")
        return 130
    except Exception as e:
        logger.exception("执行异常")
        return 1


if __name__ == "__main__":
    sys.exit(main())
