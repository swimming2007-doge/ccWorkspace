"""
Qwen 模型高级分析脚本 - 完整版
包含 TorchVista 追踪、可视化和详细结构分析
"""

import os
import sys
import torch
import torch.nn as nn
from transformers import AutoModelForCausalLM, AutoTokenizer, AutoConfig
from typing import Dict, Any, List, Tuple
import json
import time
from collections import defaultdict

# 模型路径
MODEL_PATH = r"C:\Users\Administrator\.cache\modelscope\hub\models\Qwen\Qwen2___5-1___5B-Instruct"


class LayerWiseAnalyzer:
    """逐层分析器 - 详细分析每一层的功能和参数"""

    def __init__(self, model, config):
        self.model = model
        self.config = config

    def analyze_attention_layer(self, layer_idx: int) -> Dict:
        """分析注意力层"""
        layer = self.model.model.layers[layer_idx]
        attn = layer.self_attn

        analysis = {
            "layer": layer_idx,
            "type": "Self-Attention",
            "components": {
                "q_proj": {
                    "shape": list(attn.q_proj.weight.shape),
                    "params": attn.q_proj.weight.numel(),
                    "description": "查询投影矩阵 - 生成查询向量，用于计算注意力权重",
                    "role": "将输入隐藏状态转换为查询表示",
                },
                "k_proj": {
                    "shape": list(attn.k_proj.weight.shape),
                    "params": attn.k_proj.weight.numel(),
                    "description": "键投影矩阵 - 生成键向量，用于与查询匹配",
                    "role": "将输入隐藏状态转换为键表示",
                },
                "v_proj": {
                    "shape": list(attn.v_proj.weight.shape),
                    "params": attn.v_proj.weight.numel(),
                    "description": "值投影矩阵 - 生成值向量，用于加权聚合",
                    "role": "将输入隐藏状态转换为值表示",
                },
                "o_proj": {
                    "shape": list(attn.o_proj.weight.shape),
                    "params": attn.o_proj.weight.numel(),
                    "description": "输出投影矩阵 - 将多头注意力输出投影回隐藏维度",
                    "role": "融合多头注意力结果，恢复隐藏维度",
                },
            },
            "attention_heads": self.config.num_attention_heads,
            "head_dim": self.config.hidden_size // self.config.num_attention_heads,
            "total_params": sum([
                attn.q_proj.weight.numel(),
                attn.k_proj.weight.numel(),
                attn.v_proj.weight.numel(),
                attn.o_proj.weight.numel(),
            ]),
            "formula": "Attention(Q,K,V) = softmax(QK^T / sqrt(d_k))V",
            "explanation": [
                "1. 计算查询(Q)、键(K)、值(V)向量",
                "2. 计算Q和K的点积，得到注意力分数",
                "3. 除以sqrt(d_k)进行缩放，防止梯度消失",
                "4. Softmax归一化得到注意力权重",
                "5. 用权重对V进行加权求和"
            ],
            "rotary_embedding": {
                "type": "RoPE (Rotary Position Embedding)",
                "description": "旋转位置编码 - 通过旋转向量注入位置信息",
                "advantage": "支持任意序列长度，外推能力强",
            }
        }
        return analysis

    def analyze_mlp_layer(self, layer_idx: int) -> Dict:
        """分析MLP层"""
        layer = self.model.model.layers[layer_idx]
        mlp = layer.mlp

        analysis = {
            "layer": layer_idx,
            "type": "MLP (SwiGLU)",
            "activation": "SiLU (Swish)",
            "architecture": "SwiGLU: FFN(x) = (SiLU(xW_gate) ⊙ (xW_up)) W_down",
            "components": {
                "gate_proj": {
                    "shape": list(mlp.gate_proj.weight.shape),
                    "params": mlp.gate_proj.weight.numel(),
                    "description": "门控投影 - 控制信息流通过门控机制",
                    "role": "生成门控信号，调节上投影的输出",
                },
                "up_proj": {
                    "shape": list(mlp.up_proj.weight.shape),
                    "params": mlp.up_proj.weight.numel(),
                    "description": "上投影 - 将隐藏状态投影到更高维度",
                    "role": "扩展特征空间，增加模型表达能力",
                },
                "down_proj": {
                    "shape": list(mlp.down_proj.weight.shape),
                    "params": mlp.down_proj.weight.numel(),
                    "description": "下投影 - 将高维特征投影回隐藏维度",
                    "role": "融合特征并降维，恢复隐藏空间",
                },
            },
            "intermediate_ratio": self.config.intermediate_size / self.config.hidden_size,
            "total_params": sum([
                mlp.gate_proj.weight.numel(),
                mlp.up_proj.weight.numel(),
                mlp.down_proj.weight.numel(),
            ]),
            "advantages": [
                "门控机制增强模型表达能力",
                "更高的参数效率",
                "更好的梯度流动",
                "在大型语言模型中表现优异"
            ]
        }
        return analysis

    def analyze_norm_layers(self, layer_idx: int) -> Dict:
        """分析归一化层"""
        layer = self.model.model.layers[layer_idx]

        analysis = {
            "layer": layer_idx,
            "type": "Layer Normalization",
            "norm_type": "RMSNorm (Root Mean Square Layer Normalization)",
            "components": {
                "input_layernorm": {
                    "shape": list(layer.input_layernorm.weight.shape),
                    "params": layer.input_layernorm.weight.numel(),
                    "description": "输入层归一化 - 在自注意力之前归一化",
                    "role": "稳定注意力层的输入分布",
                    "formula": "RMS(x) = x / sqrt(mean(x^2) + ε)",
                },
                "post_attention_layernorm": {
                    "shape": list(layer.post_attention_layernorm.weight.shape),
                    "params": layer.post_attention_layernorm.weight.numel(),
                    "description": "后注意力归一化 - 在MLP之前归一化",
                    "role": "稳定MLP层的输入分布",
                },
            },
            "advantages": [
                "不使用可学习的偏置项",
                "计算效率高",
                "训练稳定性好",
                "适合Transformer架构"
            ],
            "total_params": layer.input_layernorm.weight.numel() + layer.post_attention_layernorm.weight.numel()
        }
        return analysis


class TorchVistaTracer:
    """TorchVista 追踪器 - 模型执行路径追踪"""

    def __init__(self, model, tokenizer):
        self.model = model
        self.tokenizer = tokenizer
        self.traced_layers = []

    def setup_hooks(self):
        """设置前向钩子以追踪层执行"""
        self.layer_outputs = defaultdict(list)
        self.layer_inputs = defaultdict(list)

        def make_hook(layer_name):
            def hook(module, input, output):
                self.layer_inputs[layer_name].append(input[0].shape if isinstance(input, tuple) and len(input) > 0 else None)
                self.layer_outputs[layer_name].append(output.shape if hasattr(output, 'shape') else None)
            return hook

        # 注册钩子
        hooks = []
        for name, module in self.model.named_modules():
            if isinstance(module, (nn.Linear, nn.Embedding, nn.LayerNorm)):
                hook = module.register_forward_hook(make_hook(name))
                hooks.append(hook)

        return hooks

    def trace_forward(self, text: str = "Hello, how are you?"):
        """追踪前向传播"""
        print("\n" + "=" * 70)
        print("TorchVista - 前向传播追踪")
        print("=" * 70)

        # 准备输入
        inputs = self.tokenizer(text, return_tensors="pt")
        input_ids = inputs["input_ids"]
        attention_mask = inputs["attention_mask"]

        print(f"\n输入文本: '{text}'")
        print(f"Token IDs: {input_ids.tolist()}")
        print(f"输入形状: {input_ids.shape}")

        # 设置钩子
        hooks = self.setup_hooks()

        # 前向传播
        with torch.no_grad():
            start_time = time.time()
            outputs = self.model(
                input_ids=input_ids,
                attention_mask=attention_mask,
                output_hidden_states=True,
                output_attentions=False,
            )
            forward_time = time.time() - start_time

        # 移除钩子
        for hook in hooks:
            hook.remove()

        # 分析追踪结果
        print(f"\n前向传播时间: {forward_time * 1000:.2f} ms")
        print(f"\n层执行追踪:")
        print("-" * 70)

        layer_stats = []
        for layer_name in sorted(self.layer_outputs.keys()):
            if self.layer_outputs[layer_name]:
                input_shape = self.layer_inputs[layer_name][0]
                output_shape = self.layer_outputs[layer_name][0]
                layer_stats.append({
                    "name": layer_name,
                    "input": input_shape,
                    "output": output_shape
                })
                print(f"  {layer_name:50s} | 输入: {str(input_shape):20s} | 输出: {str(output_shape)}")

        return {
            "forward_time": forward_time,
            "layer_stats": layer_stats,
            "outputs": outputs
        }

    def visualize_computation_graph(self, outputs, max_nodes: int = 30):
        """可视化计算图"""
        print("\n" + "=" * 70)
        print("计算图可视化")
        print("=" * 70)

        # 打印数据流
        print("\n【数据流分析】")
        print("输入 → 嵌入层 → [Transformer层N次] → 最终归一化 → LM头 → 输出\n")

        # 详细数据流
        print("【详细数据流】")
        print(f"1. 输入: {outputs.hidden_states[0].shape} (batch, seq_len, hidden_size)")

        for i, hidden_state in enumerate(outputs.hidden_states):
            if i == 0:
                continue  # 跳过初始嵌入
            if i <= 5 or i == len(outputs.hidden_states) - 1:
                print(f"2.{i-1}. Transformer层{i-1}: {hidden_state.shape}")
            elif i == 6:
                print(f"     ... (跳过中间 {len(outputs.hidden_states) - 7} 层)")

        print(f"3. 最终输出: {outputs.logits.shape} (batch, seq_len, vocab_size)")

        # 计算每层的输出变化（近似）
        print("\n【隐藏状态统计】")
        for i, hidden_state in enumerate(outputs.hidden_states[:5]):
            mean_val = hidden_state.mean().item()
            std_val = hidden_state.std().item()
            print(f"  层 {i}: 均值={mean_val:.4f}, 标准差={std_val:.4f}")


class ModuleFunctionalityMapper:
    """模块功能映射器 - 将模块映射到具体功能"""

    def __init__(self, model, config):
        self.model = model
        self.config = config

        # 完整的功能映射
        self.function_map = {
            # 嵌入层
            "model.embed_tokens": {
                "function": "词嵌入",
                "description": "将离散的token ID转换为连续的向量表示",
                "input": "token_ids (batch, seq_len)",
                "output": "embeddings (batch, seq_len, hidden_size)",
                "parameters": f"{config.vocab_size} × {config.hidden_size}",
                "purpose": "学习每个token的语义表示，作为模型的输入",
                "key_properties": [
                    "可学习的参数矩阵",
                    "词表大小决定矩阵行数",
                    "隐藏维度决定矩阵列数"
                ]
            },
            "model.rotary_emb": {
                "function": "旋转位置编码",
                "description": "通过旋转向量为注意力机制注入位置信息",
                "input": "隐藏状态",
                "output": "添加了位置信息的隐藏状态",
                "parameters": "无 (基于预定义频率)",
                "purpose": "让模型理解token在序列中的相对位置",
                "key_properties": [
                    "可外推到更长序列",
                    "基于正弦余弦函数",
                    "逐头独立旋转"
                ],
                "advantages": [
                    "支持任意长度",
                    "位置信息在推理时可插拔",
                    "适合长文本处理"
                ]
            },
            # 注意力
            "self_attn.q_proj": {
                "function": "查询投影",
                "description": "将输入转换为查询向量，用于计算与其他位置的相关性",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"query (batch, seq_len, {config.hidden_size})",
                "formula": "Q = X @ W_Q",
                "purpose": "生成查询表示，用于搜索相关信息"
            },
            "self_attn.k_proj": {
                "function": "键投影",
                "description": "将输入转换为键向量，用于与查询匹配",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"key (batch, seq_len, {config.hidden_size})",
                "formula": "K = X @ W_K",
                "purpose": "生成键表示，用于索引信息"
            },
            "self_attn.v_proj": {
                "function": "值投影",
                "description": "将输入转换为值向量，用于聚合信息",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"value (batch, seq_len, {config.hidden_size})",
                "formula": "V = X @ W_V",
                "purpose": "生成值表示，存储实际信息内容"
            },
            "self_attn.o_proj": {
                "function": "输出投影",
                "description": "将多头注意力输出融合并投影回隐藏维度",
                "input": f"attention_output (batch, seq_len, {config.hidden_size})",
                "output": f"hidden (batch, seq_len, {config.hidden_size})",
                "formula": "O = Attention_output @ W_O",
                "purpose": "融合多头信息，恢复维度"
            },
            # MLP
            "mlp.gate_proj": {
                "function": "门控投影 (SwiGLU)",
                "description": "控制信息流的门控机制",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"gate (batch, seq_len, {config.intermediate_size})",
                "formula": "gate = SiLU(X @ W_gate)",
                "purpose": "动态调节信息通过"
            },
            "mlp.up_proj": {
                "function": "上投影 (SwiGLU)",
                "description": "扩展维度，增加表达能力",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"up (batch, seq_len, {config.intermediate_size})",
                "formula": "up = X @ W_up",
                "purpose": "扩展特征空间"
            },
            "mlp.down_proj": {
                "function": "下投影 (SwiGLU)",
                "description": "融合门控和上投影，降维回隐藏维度",
                "input": f"elementwise (batch, seq_len, {config.intermediate_size})",
                "output": f"hidden (batch, seq_len, {config.hidden_size})",
                "formula": "down = (gate ⊙ up) @ W_down",
                "purpose": "融合特征并恢复维度"
            },
            # 归一化
            "input_layernorm": {
                "function": "输入层归一化 (Pre-norm)",
                "description": "在注意力层之前归一化",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"normalized (batch, seq_len, {config.hidden_size})",
                "formula": "x̂ = x * γ / sqrt(mean(x²) + ε)",
                "position": "在自注意力之前",
                "purpose": "稳定梯度流动"
            },
            "post_attention_layernorm": {
                "function": "后注意力归一化 (Pre-norm)",
                "description": "在MLP层之前归一化",
                "input": f"attention_output (batch, seq_len, {config.hidden_size})",
                "output": f"normalized (batch, seq_len, {config.hidden_size})",
                "formula": "x̂ = x * γ / sqrt(mean(x²) + ε)",
                "position": "在MLP之前",
                "purpose": "稳定MLP输入分布"
            },
            # 输出
            "model.norm": {
                "function": "最终层归一化",
                "description": "在输出前的最终归一化",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"normalized (batch, seq_len, {config.hidden_size})",
                "purpose": "规范化最终输出"
            },
            "lm_head": {
                "function": "语言模型头",
                "description": "将隐藏状态投影到词表空间，用于预测下一个token",
                "input": f"hidden (batch, seq_len, {config.hidden_size})",
                "output": f"logits (batch, seq_len, {config.vocab_size})",
                "parameters": f"{config.vocab_size} × {config.hidden_size}",
                "formula": "logits = X @ W_lm_head",
                "purpose": "预测下一个token的概率分布"
            }
        }

    def print_functionality_map(self):
        """打印功能映射表"""
        print("\n" + "=" * 70)
        print("模块功能映射表")
        print("=" * 70)

        for module_path, info in self.function_map.items():
            print(f"\n【{module_path}】")
            print(f"  功能: {info.get('function', 'N/A')}")
            print(f"  描述: {info.get('description', 'N/A')}")

            if 'input' in info:
                print(f"  输入: {info['input']}")
            if 'output' in info:
                print(f"  输出: {info['output']}")
            if 'formula' in info:
                print(f"  公式: {info['formula']}")
            if 'parameters' in info:
                print(f"  参数: {info['parameters']}")
            if 'purpose' in info:
                print(f"  作用: {info['purpose']}")

            if 'key_properties' in info:
                print(f"  关键属性:")
                for prop in info['key_properties']:
                    print(f"    • {prop}")

            if 'advantages' in info:
                print(f"  优势:")
                for adv in info['advantages']:
                    print(f"    • {adv}")

    def get_layer_detailed_info(self, layer_idx: int) -> Dict:
        """获取指定层的详细信息"""
        layer = self.model.model.layers[layer_idx]

        info = {
            "layer_index": layer_idx,
            "components": {},
            "data_flow": {}
        }

        # 注意力
        info["components"]["self_attention"] = {
            "q_proj": {
                "shape": list(layer.self_attn.q_proj.weight.shape),
                "description": "查询投影 - 生成查询向量"
            },
            "k_proj": {
                "shape": list(layer.self_attn.k_proj.weight.shape),
                "description": "键投影 - 生成键向量"
            },
            "v_proj": {
                "shape": list(layer.self_attn.v_proj.weight.shape),
                "description": "值投影 - 生成值向量"
            },
            "o_proj": {
                "shape": list(layer.self_attn.o_proj.weight.shape),
                "description": "输出投影 - 融合多头结果"
            }
        }

        # MLP
        info["components"]["mlp"] = {
            "gate_proj": {
                "shape": list(layer.mlp.gate_proj.weight.shape),
                "description": "门控投影 - SwiGLU门控"
            },
            "up_proj": {
                "shape": list(layer.mlp.up_proj.weight.shape),
                "description": "上投影 - 扩展维度"
            },
            "down_proj": {
                "shape": list(layer.mlp.down_proj.weight.shape),
                "description": "下投影 - 融合并降维"
            }
        }

        # 归一化
        info["components"]["normalization"] = {
            "input_layernorm": {
                "shape": list(layer.input_layernorm.weight.shape),
                "type": "RMSNorm"
            },
            "post_attention_layernorm": {
                "shape": list(layer.post_attention_layernorm.weight.shape),
                "type": "RMSNorm"
            }
        }

        return info


class AdvancedQwenAnalyzer:
    """高级 Qwen 分析器 - 整合所有分析功能"""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.config = None
        self.model = None
        self.tokenizer = None

        # 子分析器
        self.layer_analyzer = None
        self.tracer = None
        self.function_mapper = None

    def load_model(self):
        """加载模型和配置"""
        print("=" * 70)
        print("加载 Qwen2.5-1.5B 模型...")
        print("=" * 70)

        self.config = AutoConfig.from_pretrained(self.model_path)
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_path)
        self.model = AutoModelForCausalLM.from_pretrained(
            self.model_path,
            torch_dtype=torch.float16,
            device_map="cpu",
            trust_remote_code=True,
        )

        print(f"✓ 模型加载成功")
        print(f"  类型: {type(self.model).__name__}")
        print(f"  参数量: {self.model.num_parameters():,}")
        print(f"  词表大小: {len(self.tokenizer)}")

        # 初始化子分析器
        self.layer_analyzer = LayerWiseAnalyzer(self.model, self.config)
        self.tracer = TorchVistaTracer(self.model, self.tokenizer)
        self.function_mapper = ModuleFunctionalityMapper(self.model, self.config)

    def print_model_overview(self):
        """打印模型概览"""
        print("\n" + "=" * 70)
        print("Qwen2.5-1.5B 模型概览")
        print("=" * 70)

        print(f"\n【基本信息】")
        print(f"  模型名称: Qwen2.5-1.5B-Instruct")
        print(f"  模型类型: {self.config.model_type}")
        print(f"  总参数量: {self.model.num_parameters():,}")
        print(f"  架构: Transformer Decoder")

        print(f"\n【架构配置】")
        print(f"  词表大小: {self.config.vocab_size}")
        print(f"  隐藏层维度: {self.config.hidden_size}")
        print(f"  Transformer层数: {self.config.num_hidden_layers}")
        print(f"  注意力头数: {self.config.num_attention_heads}")
        print(f"  注意力头维度: {self.config.hidden_size // self.config.num_attention_heads}")
        print(f"  中间层维度: {self.config.intermediate_size}")
        print(f"  最大序列长度: {getattr(self.config, 'max_position_embeddings', 'N/A')}")
        print(f"  RoPE θ: {getattr(self.config, 'rope_theta', 'N/A')}")

        print(f"\n【训练配置】")
        print(f"  词汇表: {len(self.tokenizer)}")
        print(f"  数据类型: float16")
        print(f"  Pad Token: {self.tokenizer.pad_token}")
        print(f"  EOS Token: {self.tokenizer.eos_token}")

    def analyze_sample_layers(self, num_samples: int = 3):
        """分析示例层"""
        print("\n" + "=" * 70)
        print(f"详细层分析 (展示前 {num_samples} 层)")
        print("=" * 70)

        for i in range(min(num_samples, self.config.num_hidden_layers)):
            print(f"\n{'─' * 70}")
            print(f"第 {i} 层详细分析")
            print(f"{'─' * 70}")

            # 注意力分析
            attn_analysis = self.layer_analyzer.analyze_attention_layer(i)
            print(f"\n【自注意力层】")
            print(f"  总参数量: {attn_analysis['total_params']:,}")
            print(f"  注意力头数: {attn_analysis['attention_heads']}")
            print(f"  每头维度: {attn_analysis['head_dim']}")
            print(f"  公式: {attn_analysis['formula']}")
            print(f"\n  计算步骤:")
            for step in attn_analysis['explanation']:
                print(f"    {step}")

            for comp_name, comp_info in attn_analysis['components'].items():
                print(f"\n  {comp_name}:")
                print(f"    形状: {comp_info['shape']}")
                print(f"    参数: {comp_info['params']:,}")
                print(f"    描述: {comp_info['description']}")
                print(f"    作用: {comp_info['role']}")

            print(f"\n  位置编码: {attn_analysis['rotary_embedding']['type']}")
            print(f"    描述: {attn_analysis['rotary_embedding']['description']}")
            print(f"    优势: {attn_analysis['rotary_embedding']['advantage']}")

            # MLP分析
            mlp_analysis = self.layer_analyzer.analyze_mlp_layer(i)
            print(f"\n【MLP层 (SwiGLU)】")
            print(f"  架构: {mlp_analysis['architecture']}")
            print(f"  激活函数: {mlp_analysis['activation']}")
            print(f"  总参数量: {mlp_analysis['total_params']:,}")
            print(f"  扩展比例: {mlp_analysis['intermediate_ratio']:.2f}x")

            for comp_name, comp_info in mlp_analysis['components'].items():
                print(f"\n  {comp_name}:")
                print(f"    形状: {comp_info['shape']}")
                print(f"    参数: {comp_info['params']:,}")
                print(f"    描述: {comp_info['description']}")
                print(f"    作用: {comp_info['role']}")

            print(f"\n  SwiGLU优势:")
            for adv in mlp_analysis['advantages']:
                print(f"    • {adv}")

            # 归一化分析
            norm_analysis = self.layer_analyzer.analyze_norm_layers(i)
            print(f"\n【归一化层】")
            print(f"  类型: {norm_analysis['norm_type']}")
            print(f"  总参数量: {norm_analysis['total_params']:,}")

            for comp_name, comp_info in norm_analysis['components'].items():
                print(f"\n  {comp_name}:")
                print(f"    形状: {comp_info['shape']}")
                print(f"    参数: {comp_info['params']:,}")
                print(f"    描述: {comp_info['description']}")
                print(f"    作用: {comp_info['role']}")
                if 'formula' in comp_info:
                    print(f"    公式: {comp_info['formula']}")

            print(f"\n  RMSNorm优势:")
            for adv in norm_analysis['advantages']:
                print(f"    • {adv}")

    def trace_and_visualize(self):
        """追踪并可视化模型执行"""
        trace_result = self.tracer.trace_forward()
        self.tracer.visualize_computation_graph(trace_result['outputs'])
        return trace_result

    def print_functionality_map(self):
        """打印功能映射"""
        self.function_mapper.print_functionality_map()

    def analyze_parameter_distribution(self):
        """分析参数分布"""
        print("\n" + "=" * 70)
        print("参数分布分析")
        print("=" * 70)

        param_stats = {
            "embedding": 0,
            "attention": 0,
            "mlp": 0,
            "normalization": 0,
            "output": 0,
        }

        # 嵌入层
        param_stats["embedding"] = self.model.model.embed_tokens.weight.numel()

        # Transformer层
        for layer in self.model.model.layers:
            param_stats["attention"] += sum([
                layer.self_attn.q_proj.weight.numel(),
                layer.self_attn.k_proj.weight.numel(),
                layer.self_attn.v_proj.weight.numel(),
                layer.self_attn.o_proj.weight.numel(),
            ])
            param_stats["mlp"] += sum([
                layer.mlp.gate_proj.weight.numel(),
                layer.mlp.up_proj.weight.numel(),
                layer.mlp.down_proj.weight.numel(),
            ])
            param_stats["normalization"] += sum([
                layer.input_layernorm.weight.numel(),
                layer.post_attention_layernorm.weight.numel(),
            ])

        # 最终归一化和输出
        param_stats["normalization"] += self.model.model.norm.weight.numel()
        param_stats["output"] = self.model.lm_head.weight.numel()

        total_params = sum(param_stats.values())

        print(f"\n【参数分布】")
        for component, params in param_stats.items():
            percentage = (params / total_params) * 100
            bar_length = int(percentage / 2)
            bar = "█" * bar_length
            print(f"  {component:15s}: {params:12,} ({percentage:5.2f}%) {bar}")

        print(f"\n【总结】")
        print(f"  总参数量: {total_params:,}")
        print(f"  嵌入层: {param_stats['embedding'] / total_params * 100:.2f}%")
        print(f"  注意力层: {param_stats['attention'] / total_params * 100:.2f}%")
        print(f"  MLP层: {param_stats['mlp'] / total_params * 100:.2f}%")
        print(f"  归一化层: {param_stats['normalization'] / total_params * 100:.2f}%")
        print(f"  输出层: {param_stats['output'] / total_params * 100:.2f}%")

    def print_architecture_explanation(self):
        """打印架构详细说明"""
        print("\n" + "=" * 70)
        print("Qwen2.5 架构详解")
        print("=" * 70)

        explanation = """
【Qwen2.5 是什么？】
  Qwen2.5 是阿里巴巴达摩院开发的新一代大语言模型系列，1.5B是其轻量版本。

【核心架构设计理念】

1. Transformer Decoder (仅解码器架构)
   ├─ 采用标准的自回归Transformer架构
   ├─ 通过因果掩码确保只能看到之前的信息
   └─ 适合文本生成任务

2. 自注意力机制 (Self-Attention)
   ├─ 允许模型关注输入序列的不同部分
   ├─ 捕捉长距离依赖关系
   └─ 多头注意力并行学习不同的关系模式

3. SwiGLU 激活函数
   ├─ 门控线性单元的变体
   ├─ 公式: SwiGLU(x) = SiLU(xW₁) ⊙ (xW₂)W₃
   ├─ 相比ReLU具有更好的梯度流动
   └─ 已证明在大型语言模型中性能更优

4. 旋转位置编码 (RoPE)
   ├─ 通过旋转向量注入位置信息
   ├─ 支持任意序列长度（外推能力强）
   └─ 位置信息可在推理时灵活处理

5. RMSNorm 归一化
   ├─ 均方根层归一化
   ├─ 计算效率高（无偏置项）
   ├─ Pre-norm架构（归一化在层之前）
   └─ 提高训练稳定性

【数据流动】

输入层
  │
  ├─ Token IDs [batch, seq_len]
  │
  ▼
词嵌入层
  │  功能: 将离散token转换为连续向量
  ├─ 输入: token_ids [batch, seq_len]
  ├─ 输出: embeddings [batch, seq_len, hidden_size]
  │  参数: vocab_size × hidden_size
  │
  ▼
位置编码 (RoPE)
  │  功能: 注入位置信息
  ├─ 对Q和K向量应用旋转
  ├─ 频率基于预定义的θ值
  └─ 不增加额外参数
  │
  ▼
Transformer层堆叠 (N层)
  │
  ├─ 第0层
  │   ├─ Input RMSNorm
  │   ├─ Self-Attention (MHA)
  │   │   ├─ Q投影: hidden → hidden
  │   │   ├─ K投影: hidden → hidden
  │   │   ├─ V投影: hidden → hidden
  │   │   ├─ 注意力计算: softmax(QK^T/√d)V
  │   │   └─ O投影: hidden → hidden
  │   ├─ Post-Attention RMSNorm
  │   └─ MLP (SwiGLU)
  │       ├─ Gate投影: hidden → intermediate
  │       ├─ Up投影: hidden → intermediate
  │       ├─ 元素乘积: gate ⊙ up
  │       └─ Down投影: intermediate → hidden
  │
  ├─ 第1层 (结构相同)
  │
  ├─ ...
  │
  └─ 第N-1层 (结构相同)
  │
  ▼
最终归一化
  │  功能: 规范化输出
  ├─ RMSNorm
  └─ 输出: hidden [batch, seq_len, hidden_size]
  │
  ▼
语言模型头 (LM Head)
  │  功能: 预测下一个token
  ├─ 输入: hidden [batch, seq_len, hidden_size]
  ├─ 投影: logits = hidden @ W_lm_head
  └─ 输出: logits [batch, seq_len, vocab_size]
  │
  ▼
输出 (logits → 概率分布 → 采样)
  ├─ Softmax: logits → probabilities
  └─ 采样/贪婪解码: 选择下一个token

【关键技术要点】

1. Flash Attention (如使用)
   ├─ 优化注意力计算，减少显存使用
   ├─ 减少内存访问次数
   └─ 提高训练和推理速度

2. KV Cache (推理优化)
   ├─ 缓存之前计算的K和V
   ├─ 避免重复计算历史token
   └─ 加速自回归生成

3. 分组查询注意力 (GQA - 可选)
   ├─ 多个查询头共享键值头
   ├─ 减少推理时的显存占用
   └─ 保持模型性能

【训练策略】

1. 预训练
   ├─ 大规模语料库
   ├─ 下一个token预测目标
   └─ 学习通用的语言理解

2. 指令微调 (Instruct)
   ├─ 人类指令数据
   ├─ 对话格式训练
   └─ 提升任务遵循能力

3. 对齐优化
   ├─ RLHF或DPO
   ├─ 人类反馈学习
   └─ 安全性和有用性平衡

【优势总结】

✓ 效率: SwiGLU + RMSNorm 高效架构
✓ 性能: 在多个基准测试中表现优异
✓ 可扩展: 支持长序列和多任务
✓ 开放: 开源模型，可商业使用
✓ 多语言: 支持中文、英文等多种语言
        """

        print(explanation)

    def export_full_report(self, output_file: str = "full_model_analysis_report.md"):
        """导出完整报告"""
        print(f"\n正在导出完整报告到 {output_file}...")

        with open(output_file, "w", encoding="utf-8") as f:
            f.write("# Qwen2.5-1.5B 模型完整分析报告\n\n")
            f.write("---\n\n")

            # 模型概览
            f.write("## 模型概览\n\n")
            f.write(f"- **模型名称**: Qwen2.5-1.5B-Instruct\n")
            f.write(f"- **模型类型**: {self.config.model_type}\n")
            f.write(f"- **总参数量**: {self.model.num_parameters():,}\n")
            f.write(f"- **架构**: Transformer Decoder\n\n")

            # 配置信息
            f.write("## 配置信息\n\n")
            f.write("| 参数 | 值 |\n")
            f.write("|------|-----|\n")
            f.write(f"| 词表大小 | {self.config.vocab_size} |\n")
            f.write(f"| 隐藏层维度 | {self.config.hidden_size} |\n")
            f.write(f"| Transformer层数 | {self.config.num_hidden_layers} |\n")
            f.write(f"| 注意力头数 | {self.config.num_attention_heads} |\n")
            f.write(f"| 中间层维度 | {self.config.intermediate_size} |\n")
            f.write(f"| 最大序列长度 | {getattr(self.config, 'max_position_embeddings', 'N/A')} |\n")

            # 层级详细分析
            f.write("\n## 层级详细分析\n\n")
            for i in range(min(3, self.config.num_hidden_layers)):
                f.write(f"### 第 {i} 层\n\n")

                # 注意力
                attn = self.layer_analyzer.analyze_attention_layer(i)
                f.write("#### 自注意力层\n\n")
                f.write(f"- **参数量**: {attn['total_params']:,}\n")
                f.write(f"- **注意力头数**: {attn['attention_heads']}\n")
                f.write(f"- **公式**: {attn['formula']}\n\n")

                # MLP
                mlp = self.layer_analyzer.analyze_mlp_layer(i)
                f.write("#### MLP层 (SwiGLU)\n\n")
                f.write(f"- **参数量**: {mlp['total_params']:,}\n")
                f.write(f"- **架构**: {mlp['architecture']}\n\n")

            # 参数分布
            f.write("\n## 参数分布\n\n")

            param_stats = {
                "embedding": self.model.model.embed_tokens.weight.numel(),
                "output": self.model.lm_head.weight.numel(),
                "normalization": self.model.model.norm.weight.numel(),
            }

            for layer in self.model.model.layers:
                param_stats.setdefault("attention", 0)
                param_stats.setdefault("mlp", 0)
                param_stats.setdefault("normalization", 0)
                param_stats["attention"] += sum([
                    layer.self_attn.q_proj.weight.numel(),
                    layer.self_attn.k_proj.weight.numel(),
                    layer.self_attn.v_proj.weight.numel(),
                    layer.self_attn.o_proj.weight.numel(),
                ])
                param_stats["mlp"] += sum([
                    layer.mlp.gate_proj.weight.numel(),
                    layer.mlp.up_proj.weight.numel(),
                    layer.mlp.down_proj.weight.numel(),
                ])
                param_stats["normalization"] += sum([
                    layer.input_layernorm.weight.numel(),
                    layer.post_attention_layernorm.weight.numel(),
                ])

            total = sum(param_stats.values())
            f.write("| 组件 | 参数量 | 占比 |\n")
            f.write("|------|--------|------|\n")
            for comp, params in param_stats.items():
                f.write(f"| {comp} | {params:,} | {params/total*100:.2f}% |\n")

            f.write("\n---\n\n")
            f.write("*报告生成时间: " + time.strftime("%Y-%m-%d %H:%M:%S") + "*\n")

        print(f"✓ 完整报告已导出到 {output_file}")

    def run_comprehensive_analysis(self):
        """运行全面分析"""
        # 加载模型
        self.load_model()

        # 模型概览
        self.print_model_overview()

        # 层级分析
        self.analyze_sample_layers(num_samples=3)

        # TorchVista追踪
        self.trace_and_visualize()

        # 功能映射
        self.print_functionality_map()

        # 参数分布
        self.analyze_parameter_distribution()

        # 架构解释
        self.print_architecture_explanation()

        # 导出报告
        self.export_full_report()

        print("\n" + "=" * 70)
        print("✓ 全面分析完成！")
        print("=" * 70)


def main():
    """主函数"""
    analyzer = AdvancedQwenAnalyzer(MODEL_PATH)
    analyzer.run_comprehensive_analysis()


if __name__ == "__main__":
    main()
