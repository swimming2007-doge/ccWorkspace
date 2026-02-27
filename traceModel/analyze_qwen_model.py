"""
Qwen 模型结构分析脚本
使用 torchvista 和 transformers 进行模型追踪和结构分析
"""

import os
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, AutoConfig
from typing import Dict, Any
import json

# 模型路径
MODEL_PATH = r"C:\Users\Administrator\.cache\modelscope\hub\models\Qwen\Qwen2___5-1___5B-Instruct"


class QwenModelAnalyzer:
    """Qwen 模块分析器"""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.config = None
        self.model = None
        self.tokenizer = None

        # 模块功能说明字典
        self.module_descriptions = {
            # 核心组件
            "Qwen2Model": "Qwen2核心模型，包含嵌入层、Transformer层和输出层",
            "Qwen2ForCausalLM": "Qwen2因果语言模型，在核心模型之上添加了语言模型头",

            # 嵌入层
            "Qwen2Embedding": "可学习的词嵌入层，将token ID转换为向量表示",
            "RotaryEmbedding": "旋转位置编码，为自注意力机制提供相对位置信息",

            # 注意力机制
            "Qwen2Attention": "多头注意力机制模块，负责计算输入序列中不同位置之间的关系",
            "Attention": "基础注意力计算单元",
            "flash_attn_func": "Flash Attention优化函数，加速注意力计算并减少显存使用",

            # 前馈网络
            "Qwen2MLP": "多层感知机模块，使用SwiGLU激活函数的MLP结构",
            "GatedMlp": "门控MLP，通过门控机制增强模型表达能力",

            # 层归一化
            "Qwen2RMSNorm": "均方根层归一化，稳定训练过程，防止梯度消失/爆炸",

            # 输出层
            "Qwen2CausalLMOutputWithPast": "因果语言模型输出类，包含损失、logits和隐藏状态",
            "lm_head": "语言模型头，将隐藏状态投影到词表大小，用于预测下一个token",

            # 其他
            "DynamicCache": "动态缓存，用于存储推理过程中的键值对，支持KV Cache优化",
            "CausalLMOutputWithPast": "包含过去键值对的标准输出格式",
        }

        # 层功能详细说明
        self.layer_descriptions = {
            "embed_tokens": "词嵌入层：将输入的token索引转换为连续的词向量表示",
            "layers": "Transformer解码器层堆叠：包含自注意力和前馈网络",
            "norm": "最终的层归一化：对输出进行归一化处理",
            "rotary_emb": "旋转位置编码：生成位置编码向量，注入到注意力计算中",
            "q_proj": "查询投影：将隐藏状态投影为查询向量",
            "k_proj": "键投影：将隐藏状态投影为键向量",
            "v_proj": "值投影：将隐藏状态投影为值向量",
            "o_proj": "输出投影：将注意力输出投影回隐藏维度",
            "gate_proj": "门控投影：SwiGLU中的门控分支",
            "up_proj": "上投影：SwiGLU中的上投影分支",
            "down_proj": "下投影：SwiGLU中的下投影分支，合并两个分支的输出",
            "input_layernorm": "输入层归一化：对注意力层的输入进行归一化",
            "post_attention_layernorm": "后注意力层归一化：对注意力输出进行归一化，进入MLP",
            "self_attn": "自注意力层：计算序列内部的注意力权重",
            "mlp": "前馈网络层：处理注意力输出，提取更深层的特征",
        }

    def load_model(self):
        """加载模型和配置"""
        print("=" * 60)
        print("正在加载 Qwen 模型...")
        print("=" * 60)

        # 加载配置
        self.config = AutoConfig.from_pretrained(self.model_path)
        print(f"\n✓ 配置文件加载成功")

        # 加载 tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_path)
        print(f"✓ Tokenizer 加载成功")
        print(f"  - 词表大小: {len(self.tokenizer)}")
        print(f"  - 上下文长度: {self.tokenizer.model_max_length}")

        # 加载模型（使用半精度节省内存）
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.float16,
            device_map="cpu",  # 先加载到CPU，后续可移到GPU
            trust_remote_code=True,
        )
        print(f"✓ 模型加载成功")
        print(f"  - 模型类型: {type(self.model).__name__}")
        print(f"  - 参数数量: {self.model.num_parameters():,}")

    def print_model_config(self):
        """打印模型配置信息"""
        print("\n" + "=" * 60)
        print("模型配置详情")
        print("=" * 60)

        config_dict = self.config.to_dict()
        for key, value in config_dict.items():
            print(f"  {key}: {value}")

    def analyze_model_structure(self):
        """分析模型结构"""
        print("\n" + "=" * 60)
        print("模型结构分析")
        print("=" * 60)

        self._print_module_tree(self.model, level=0)

    def _print_module_tree(self, module, level=0):
        """递归打印模块树结构"""
        indent = "  " * level
        module_name = module.__class__.__name__
        module_type = type(module).__name__

        # 获取模块功能描述
        description = self.module_descriptions.get(
            module_type, ""
        )
        description = f" - {description}" if description else ""

        # 获取参数数量
        num_params = sum(p.numel() for p in module.parameters())

        # 打印模块信息
        print(f"{indent}├─ {module_name} ({module_type}){description}")
        if num_params > 0:
            print(f"{indent}   参数: {num_params:,}")

        # 递归打印子模块
        for name, child in module.named_children():
            child_indent = "  " * (level + 1)
            child_name = child.__class__.__name__
            child_type = type(child).__name__

            child_desc = self.layer_descriptions.get(name, "")
            child_desc = f" - {child_desc}" if child_desc else ""

            child_params = sum(p.numel() for p in child.parameters())

            print(f"{child_indent}├─ {name}: {child_name} ({child_type}){child_desc}")
            if child_params > 0:
                print(f"{child_indent}   参数: {child_params:,}")

            # 继续递归子模块（最多再深入一层）
            if level < 1:
                self._print_module_tree(child, level + 2)

    def print_detailed_layer_analysis(self):
        """详细的层级分析"""
        print("\n" + "=" * 60)
        print("详细层级分析")
        print("=" * 60)

        # 分析嵌入层
        print("\n【1. 嵌入层 (Embedding Layer)】")
        print(f"  - embed_tokens: 词嵌入矩阵")
        print(f"    维度: ({self.config.vocab_size}, {self.config.hidden_size})")
        print(f"    功能: 将 {self.config.vocab_size} 个token映射到 {self.config.hidden_size} 维向量空间")

        # 分析Transformer层
        print(f"\n【2. Transformer解码器层 (Decoder Layers: {self.config.num_hidden_layers}层)】")
        for i in range(min(3, self.config.num_hidden_layers)):  # 显示前3层
            layer = self.model.model.layers[i]
            print(f"\n  第 {i} 层结构:")

            # 自注意力
            q_proj = layer.self_attn.q_proj.weight.shape
            k_proj = layer.self_attn.k_proj.weight.shape
            v_proj = layer.self_attn.v_proj.weight.shape
            o_proj = layer.self_attn.o_proj.weight.shape

            print(f"    自注意力 (Self-Attention):")
            print(f"      - Q投影: {q_proj[0]}×{q_proj[1]}")
            print(f"      - K投影: {k_proj[0]}×{k_proj[1]}")
            print(f"      - V投影: {v_proj[0]}×{v_proj[1]}")
            print(f"      - O投影: {o_proj[0]}×{o_proj[1]}")
            print(f"      - 注意力头数: {self.config.num_attention_heads}")
            print(f"      - 每头维度: {self.config.hidden_size // self.config.num_attention_heads}")

            # MLP
            gate_proj = layer.mlp.gate_proj.weight.shape
            up_proj = layer.mlp.up_proj.weight.shape
            down_proj = layer.mlp.down_proj.weight.shape

            print(f"    前馈网络 (MLP - SwiGLU):")
            print(f"      - 门控投影: {gate_proj[0]}×{gate_proj[1]}")
            print(f"      - 上投影: {up_proj[0]}×{up_proj[1]}")
            print(f"      - 下投影: {down_proj[0]}×{down_proj[1]}")
            print(f"      - 中间维度: {self.config.intermediate_size}")

            # 层归一化
            print(f"    层归一化:")
            print(f"      - 输入归一化: RMSNorm ({self.config.hidden_size})")
            print(f"      - 后注意力归一化: RMSNorm ({self.config.hidden_size})")

        if self.config.num_hidden_layers > 3:
            print(f"\n  ... 剩余 {self.config.num_hidden_layers - 3} 层结构相同")

        # 分析输出层
        print(f"\n【3. 输出层 (Output Layer)】")
        lm_head = self.model.lm_head.weight.shape
        print(f"  - lm_head: 语言模型头")
        print(f"    维度: {lm_head[0]}×{lm_head[1]}")
        print(f"    功能: 将 {lm_head[1]} 维隐藏状态投影到 {lm_head[0]} 个词的logits")

    def trace_model_with_torchvista(self, sample_input=None):
        """使用torchvista追踪模型"""
        print("\n" + "=" * 60)
        print("使用 TorchVista 追踪模型")
        print("=" * 60)

        try:
            import torchvista as tv
            print("✓ TorchVista 已导入")
        except ImportError:
            print("⚠ TorchVista 未安装，尝试安装...")
            os.system("pip install torchvista -q")
            import torchvista as tv
            print("✓ TorchVista 安装完成")

        # 准备示例输入
        if sample_input is None:
            sample_text = "Hello, how are you?"
            inputs = self.tokenizer(sample_text, return_tensors="pt")
            input_ids = inputs["input_ids"]
            attention_mask = inputs["attention_mask"]
        else:
            input_ids, attention_mask = sample_input

        print(f"\n示例输入: '{sample_text}'")
        print(f"Token IDs: {input_ids.tolist()}")

        # 创建追踪器
        with torch.no_grad():
            # 执行前向传播
            outputs = self.model(input_ids=input_ids, attention_mask=attention_mask, output_hidden_states=True)

            print(f"\n输出形状:")
            print(f"  - Logits: {outputs.logits.shape}")
            print(f"  - Hidden states: {len(outputs.hidden_states)} 层")

        # 可视化计算图
        print("\n正在生成计算图可视化...")

        # 使用torchvista创建可视化
        try:
            # 创建图追踪
            graph = tv.Graph()
            graph.add_node("input_ids", input_ids.shape)
            graph.add_node("attention_mask", attention_mask.shape)
            graph.add_node("embed_tokens", (input_ids.shape[0], input_ids.shape[1], self.config.hidden_size))

            # 添加每层的追踪
            for i in range(min(5, self.config.num_hidden_layers)):
                layer_name = f"layer_{i}"
                graph.add_node(layer_name, (input_ids.shape[0], input_ids.shape[1], self.config.hidden_size))

            graph.add_node("output", outputs.logits.shape)

            print("✓ 计算图创建完成")
            print("\n节点信息:")
            for node_name, node_shape in graph.nodes.items():
                print(f"  {node_name}: {node_shape}")

        except Exception as e:
            print(f"⚠ 可视化过程中出现错误: {e}")
            print("继续进行模型分析...")

    def print_architecture_summary(self):
        """打印架构总结"""
        print("\n" + "=" * 60)
        print("Qwen2.5-1.5B 模型架构总结")
        print("=" * 60)

        summary = """
【模型概览】
  Qwen2.5 是阿里巴巴开发的大型语言模型系列，1.5B版本是其轻量级版本。

【架构特点】
  1. Transformer Decoder 架构
     - 标准的自回归语言模型架构
     - 使用旋转位置编码 (RoPE)
     - 支持 KV Cache 推理加速

  2. 注意力机制
     - 多头注意力 (MHA)
     - 使用 Flash Attention 优化
     - 分组查询注意力 (GQA) 可能用于大版本

  3. 前馈网络
     - SwiGLU 激活函数
     - 中间层维度扩展 (~4x)

  4. 归一化
     - RMSNorm (Root Mean Square Layer Normalization)
     - Pre-norm 架构 (归一化在注意力/MLP之前)

  5. 位置编码
     - 旋转位置编码 (Rotary Positional Embedding)
     - 可以处理变长序列

【关键参数】
  - 词表大小: {vocab_size}
  - 隐藏层维度: {hidden_size}
  - 注意力头数: {num_attention_heads}
  - 隐藏层数: {num_hidden_layers}
  - 中间层维度: {intermediate_size}
  - 最大序列长度: {max_position_embeddings}
  - RoPE theta: {rope_theta}

【模型工作流程】
  1. 输入 Token IDs → 嵌入层 → 词向量
  2. 添加位置编码 (RoPE)
  3. 通过 {num_hidden_layers} 层 Transformer Decoder:
     a. 每层包含:
        - 自注意力层
        - 前馈网络 (MLP)
        - 两层 RMSNorm
  4. 最终层归一化
  5. LM Head 投影到词表 → 输出 Logits

【应用场景】
  - 文本生成
  - 对话系统
  - 代码生成
  - 问答系统
  - 文本摘要
        """.format(
            vocab_size=self.config.vocab_size,
            hidden_size=self.config.hidden_size,
            num_attention_heads=self.config.num_attention_heads,
            num_hidden_layers=self.config.num_hidden_layers,
            intermediate_size=self.config.intermediate_size,
            max_position_embeddings=getattr(self.config, 'max_position_embeddings', 'N/A'),
            rope_theta=getattr(self.config, 'rope_theta', 'N/A'),
        )

        print(summary)

    def export_structure_report(self, output_file="model_structure_report.txt"):
        """导出结构分析报告"""
        print(f"\n正在导出报告到 {output_file}...")

        with open(output_file, "w", encoding="utf-8") as f:
            f.write("Qwen2.5-1.5B 模型结构分析报告\n")
            f.write("=" * 60 + "\n\n")

            # 配置信息
            f.write("【模型配置】\n")
            for key, value in self.config.to_dict().items():
                f.write(f"  {key}: {value}\n")
            f.write("\n")

            # 层级分析
            f.write("【层级分析】\n")
            f.write(f"嵌入层: embed_tokens ({self.config.vocab_size}, {self.config.hidden_size})\n")
            f.write(f"解码器层数: {self.config.num_hidden_layers}\n")
            f.write(f"每层包含:\n")
            f.write(f"  - 自注意力: Q/K/V/O 投影\n")
            f.write(f"  - MLP: gate/up/down 投影 (SwiGLU)\n")
            f.write(f"  - RMSNorm: 输入和后注意力归一化\n")
            f.write(f"\n输出层: lm_head ({self.config.vocab_size}, {self.config.hidden_size})\n")

            # 参数统计
            total_params = sum(p.numel() for p in self.model.parameters())
            f.write(f"\n【参数统计】\n")
            f.write(f"总参数量: {total_params:,}\n")

        print(f"✓ 报告已导出到 {output_file}")

    def run_full_analysis(self):
        """运行完整的模型分析"""
        # 加载模型
        self.load_model()

        # 打印配置
        self.print_model_config()

        # 分析结构
        self.analyze_model_structure()

        # 详细层级分析
        self.print_detailed_layer_analysis()

        # 使用torchvista追踪
        self.trace_model_with_torchvista()

        # 打印架构总结
        self.print_architecture_summary()

        # 导出报告
        self.export_structure_report()

        print("\n" + "=" * 60)
        print("分析完成！")
        print("=" * 60)


def main():
    """主函数"""
    analyzer = QwenModelAnalyzer(MODEL_PATH)
    analyzer.run_full_analysis()


if __name__ == "__main__":
    main()
