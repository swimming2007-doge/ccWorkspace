"""
Qwen 模型快速分析脚本
通过配置文件快速分析模型结构，无需加载完整模型
"""

import os
import sys
import json
from typing import Dict, Any

# 修复Windows编码问题
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# 模型路径
MODEL_PATH = r"C:\Users\Administrator\.cache\modelscope\hub\models\Qwen\Qwen2___5-1___5B-Instruct"


class QuickQwenAnalyzer:
    """快速 Qwen 分析器 - 基于配置文件分析"""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.config = None
        self.generation_config = None
        self.tokenizer_config = None

        # 完整的模块功能说明字典
        self.module_functionality = {
            # ============== 核心组件 ==============
            "Qwen2Model": {
                "chinese_name": "Qwen2核心模型",
                "description": "Qwen2的核心Transformer模型，包含嵌入层、解码器层和输出归一化层",
                "components": [
                    "词嵌入层 (embed_tokens)",
                    "位置编码 (rotary_emb)",
                    "Transformer解码器层 (layers)",
                    "最终归一化 (norm)"
                ],
                "purpose": "处理输入序列，生成隐藏状态表示"
            },

            "Qwen2ForCausalLM": {
                "chinese_name": "Qwen2因果语言模型",
                "description": "在Qwen2Model基础上添加语言模型头的完整模型，用于下一个token预测",
                "components": [
                    "Qwen2Model (核心模型)",
                    "语言模型头 (lm_head)"
                ],
                "purpose": "因果语言建模，文本生成"
            },

            # ============== 嵌入层 ==============
            "model.embed_tokens": {
                "chinese_name": "词嵌入层",
                "description": "可学习的词嵌入矩阵，将离散的token ID转换为连续的向量表示",
                "input": "token_ids [batch, seq_len]",
                "output": "embeddings [batch, seq_len, hidden_size]",
                "formula": "embedding = W[token_id]",
                "role": "学习每个token的语义表示",
                "key_points": [
                    "可学习的参数矩阵，大小为 vocab_size × hidden_size",
                    "相似的token在嵌入空间中有相近的表示",
                    "是模型理解语义的第一步"
                ],
                "in_qwen": "Qwen使用标准的词嵌入，与BERT、GPT等模型相同"
            },

            "model.rotary_emb": {
                "chinese_name": "旋转位置编码 (RoPE)",
                "description": "通过旋转向量方式为注意力机制注入位置信息，不增加额外参数",
                "input": "查询和键向量",
                "output": "添加了位置信息的Q和K向量",
                "formula": "q' = q * cos(mθ) + rotate_90(q) * sin(mθ)",
                "role": "让模型理解token在序列中的相对位置",
                "key_points": [
                    "基于正弦余弦函数的旋转",
                    "相对位置编码，不是绝对位置",
                    "可外推到更长的序列（训练长度之外）",
                    "不增加可训练参数"
                ],
                "advantages": [
                    "支持任意长度的序列",
                    "位置信息在推理时可插拔",
                    "在长文本任务中表现优异",
                    "比传统绝对位置编码更灵活"
                ],
                "rope_theta": "控制位置编码频率的θ参数，影响模型对不同距离的敏感度"
            },

            # ============== 自注意力机制 ==============
            "model.layers.*.self_attn": {
                "chinese_name": "自注意力层",
                "description": "多头自注意力机制，计算序列中每个位置与其他所有位置的相关性",
                "formula": "Attention(Q,K,V) = softmax(QK^T / √d_k) V",
                "purpose": "捕捉序列中的长距离依赖关系",
                "computation_steps": [
                    "1. Q投影: 将输入转换为查询向量",
                    "2. K投影: 将输入转换为键向量",
                    "3. V投影: 将输入转换为值向量",
                    "4. 注意力分数: 计算Q和K的点积并缩放",
                    "5. Softmax归一化: 将分数转换为概率分布",
                    "6. 加权求和: 用概率对V进行加权"
                ],
                "multi_head": {
                    "concept": "多头注意力",
                    "description": "将隐藏维度分为多个头，每个头独立计算注意力",
                    "advantage": "可以同时捕捉不同类型的关系（如句法、语义等）"
                },
                "components": {
                    "q_proj": "查询投影: X @ W_Q",
                    "k_proj": "键投影: X @ W_K",
                    "v_proj": "值投影: X @ W_V",
                    "o_proj": "输出投影:多头结果融合"
                }
            },

            "model.layers.*.self_attn.q_proj": {
                "chinese_name": "查询投影层",
                "description": "将输入隐藏状态投影为查询向量，用于搜索相关信息",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "query [batch, num_heads, seq_len, head_dim]",
                "formula": "Q = X @ W_Q",
                "role": "生成查询表示，每个位置的查询向量会在整个序列中寻找匹配的键",
                "in_qwen": "Qwen使用线性投影，形状为 [hidden_size, hidden_size]"
            },

            "model.layers.*.self_attn.k_proj": {
                "chinese_name": "键投影层",
                "description": "将输入隐藏状态投影为键向量，用于与查询匹配",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "key [batch, num_heads, seq_len, head_dim]",
                "formula": "K = X @ W_K",
                "role": "生成键表示，作为信息的索引"
            },

            "model.layers.*.self_attn.v_proj": {
                "chinese_name": "值投影层",
                "description": "将输入隐藏状态投影为值向量，存储实际信息内容",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "value [batch, num_heads, seq_len, head_dim]",
                "formula": "V = X @ W_V",
                "role": "生成值表示，包含需要被聚合的实际信息"
            },

            "model.layers.*.self_attn.o_proj": {
                "chinese_name": "输出投影层",
                "description": "将多头注意力的输出融合，投影回原始隐藏维度",
                "input": "attention_output [batch, seq_len, hidden_size]",
                "output": "hidden [batch, seq_len, hidden_size]",
                "formula": "O = Attention_output @ W_O",
                "role": "融合多头注意力的结果，恢复到隐藏维度"
            },

            # ============== 前馈网络 ==============
            "model.layers.*.mlp": {
                "chinese_name": "前馈网络层 (MLP)",
                "description": "使用SwiGLU激活函数的门控前馈网络，在注意力层之后处理信息",
                "activation": "SiLU (Swish)",
                "architecture": "SwiGLU",
                "formula": "FFN(x) = (SiLU(x @ W_gate) ⊙ (x @ W_up)) @ W_down",
                "purpose": "提取深层特征，增加模型非线性能力",
                "key_points": [
                    "SwiGLU是GLU的改进版本",
                    "相比ReLU有更好的梯度流动",
                    "门控机制动态控制信息流",
                    "在大型语言模型中性能优异"
                ],
                "components": {
                    "gate_proj": "门控投影 - 控制信息通过",
                    "up_proj": "上投影 - 扩展维度",
                    "down_proj": "下投影 - 融合降维"
                }
            },

            "model.layers.*.mlp.gate_proj": {
                "chinese_name": "门控投影层",
                "description": "SwiGLU架构中的门控分支，控制信息的流动",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "gate [batch, seq_len, intermediate_size]",
                "formula": "gate = SiLU(X @ W_gate)",
                "role": "生成0-1之间的门控值，动态调节上投影的输出",
                "explanation": "门控机制使模型能够选择性地传递信息，类似LSTM的门控"
            },

            "model.layers.*.mlp.up_proj": {
                "chinese_name": "上投影层",
                "description": "SwiGLU架构中的上投影分支，扩展隐藏维度",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "up [batch, seq_len, intermediate_size]",
                "formula": "up = X @ W_up",
                "role": "将特征投影到更高维空间，增加表达能力",
                "expansion_ratio": "通常扩展到4倍，即 intermediate_size ≈ 4 × hidden_size"
            },

            "model.layers.*.mlp.down_proj": {
                "chinese_name": "下投影层",
                "description": "SwiGLU架构中的下投影分支，融合门控和上投影结果并降维",
                "input": "elementwise [batch, seq_len, intermediate_size]",
                "output": "hidden [batch, seq_len, hidden_size]",
                "formula": "down = (gate ⊙ up) @ W_down",
                "role": "融合两个分支的特征，并投影回原始维度",
                "explanation": "先进行元素级乘积（门控调节），然后降维"
            },

            # ============== 归一化层 ==============
            "model.layers.*.input_layernorm": {
                "chinese_name": "输入层归一化",
                "description": "在自注意力层之前对输入进行归一化",
                "type": "RMSNorm (Root Mean Square Layer Normalization)",
                "position": "Pre-norm架构（在层之前归一化）",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "normalized [batch, seq_len, hidden_size]",
                "formula": "x̂ = x * γ / sqrt(mean(x²) + ε)",
                "role": "稳定注意力层的输入分布，防止数值不稳定",
                "key_points": [
                    "只使用可学习的缩放参数γ，无偏置",
                    "计算效率高，比标准LayerNorm更快",
                    "在Transformer中表现优异",
                    "Pre-norm有助于深层网络的训练"
                ],
                "difference_from_layernorm": "RMSNorm不计算均值，只计算均方根，更简洁"
            },

            "model.layers.*.post_attention_layernorm": {
                "chinese_name": "后注意力层归一化",
                "description": "在MLP层之前对注意力输出进行归一化",
                "type": "RMSNorm",
                "position": "在注意力之后，MLP之前",
                "input": "attention_output [batch, seq_len, hidden_size]",
                "output": "normalized [batch, seq_len, hidden_size]",
                "formula": "x̂ = x * γ / sqrt(mean(x²) + ε)",
                "role": "稳定MLP层的输入分布"
            },

            "model.norm": {
                "chinese_name": "最终归一化层",
                "description": "在所有Transformer层之后，输出之前的最终归一化",
                "type": "RMSNorm",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "normalized [batch, seq_len, hidden_size]",
                "role": "规范化最终输出，为语言模型头准备输入"
            },

            # ============== 输出层 ==============
            "lm_head": {
                "chinese_name": "语言模型头",
                "description": "将隐藏状态投影到词表空间，用于预测下一个token",
                "input": "hidden [batch, seq_len, hidden_size]",
                "output": "logits [batch, seq_len, vocab_size]",
                "formula": "logits = X @ W_lm_head",
                "role": "预测每个位置下一个token的概率分布",
                "tie_with_embedding": "在许多模型中，lm_head与embed_tokens共享权重",
                "next_token_prediction": "通过softmax将logits转换为概率，然后采样下一个token",
                "in_qwen": "Qwen通常共享embed_tokens和lm_head的权重，节省参数"
            },

            # ============== 其他组件 ==============
            "DynamicCache": {
                "chinese_name": "动态缓存",
                "description": "用于推理过程中缓存已计算token的键值对",
                "purpose": "加速自回归生成，避免重复计算",
                "kv_cache": "键值缓存，存储每层的K和V向量",
                "inference_optimization": "生成时只需计算新token的注意力，历史token的K和V从缓存读取",
                "memory_benefit": "将推理复杂度从O(n²)降低到O(n)"
            },

            "CausalLMOutputWithPast": {
                "chinese_name": "因果语言模型输出",
                "description": "包含损失、logits、隐藏状态和过去键值对的输出格式",
                "components": [
                    "loss: 语言模型损失（训练时）",
                    "logits: 预测logits",
                    "hidden_states: 每层的隐藏状态",
                    "past_key_values: 缓存的键值对（推理时）"
                ]
            }
        }

        # Qwen特定架构说明
        self.qwen_architecture = {
            "overview": "Qwen2.5是阿里巴巴达摩院开发的新一代大语言模型，采用先进的Transformer Decoder架构",
            "key_features": [
                "SwiGLU激活函数 - 提升性能",
                "RMSNorm归一化 - 稳定训练",
                "RoPE位置编码 - 支持长序列",
                "Pre-norm架构 - 深层网络训练稳定",
                "Flash Attention优化 - 加速计算"
            ],
            "training_phases": [
                "预训练: 大规模语料库学习语言知识",
                "指令微调: 学习遵循指令的能力",
                "对齐优化: RLHF/DPO提升有用性和安全性"
            ]
        }

    def load_configs(self):
        """加载配置文件"""
        print("=" * 70)
        print("加载 Qwen2.5-1.5B 模型配置...")
        print("=" * 70)

        # 加载主配置
        config_path = os.path.join(self.model_path, "config.json")
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = json.load(f)
        print("✓ config.json 加载成功")

        # 加载生成配置
        gen_config_path = os.path.join(self.model_path, "generation_config.json")
        with open(gen_config_path, 'r', encoding='utf-8') as f:
            self.generation_config = json.load(f)
        print("✓ generation_config.json 加载成功")

        # 加载tokenizer配置
        tokenizer_config_path = os.path.join(self.model_path, "tokenizer_config.json")
        with open(tokenizer_config_path, 'r', encoding='utf-8') as f:
            self.tokenizer_config = json.load(f)
        print("✓ tokenizer_config.json 加载成功")

    def print_basic_info(self):
        """打印基本信息"""
        print("\n" + "=" * 70)
        print("Qwen2.5-1.5B 模型基本信息")
        print("=" * 70)

        print(f"\n【模型概览】")
        print(f"  模型名称: Qwen2.5-1.5B-Instruct")
        print(f"  模型类型: {self.config.get('model_type', 'Qwen2ForCausalLM')}")
        print(f"  架构: Transformer Decoder")

        print(f"\n【核心配置】")
        print(f"  词表大小: {self.config.get('vocab_size', 'N/A')}")
        print(f"  隐藏层维度: {self.config.get('hidden_size', 'N/A')}")
        print(f"  Transformer层数: {self.config.get('num_hidden_layers', 'N/A')}")
        print(f"  注意力头数: {self.config.get('num_attention_heads', 'N/A')}")
        print(f"  中间层维度: {self.config.get('intermediate_size', 'N/A')}")

        # 计算参数量（近似）
        hidden_size = self.config.get('hidden_size', 1536)
        num_layers = self.config.get('num_hidden_layers', 28)
        num_heads = self.config.get('num_attention_heads', 12)
        vocab_size = self.config.get('vocab_size', 151936)
        intermediate_size = self.config.get('intermediate_size', 8960)

        head_dim = hidden_size // num_heads

        # 嵌入层参数
        embedding_params = vocab_size * hidden_size

        # 每层参数
        per_layer_params = (
            # 注意力
            4 * hidden_size * hidden_size +  # Q, K, V, O 投影
            # MLP (SwiGLU)
            3 * hidden_size * intermediate_size +  # gate, up, down
            # 归一化
            2 * hidden_size  # 两个RMSNorm
        )

        # Transformer层参数
        transformer_params = per_layer_params * num_layers

        # 最终归一化
        final_norm_params = hidden_size

        # 输出层（通常与嵌入共享权重）
        output_params = vocab_size * hidden_size  # lm_head

        total_params = embedding_params + transformer_params + final_norm_params + output_params

        print(f"\n【参数量估算】")
        print(f"  嵌入层: {embedding_params:,}")
        print(f"  Transformer层 (×{num_layers}): {transformer_params:,}")
        print(f"  最终归一化: {final_norm_params:,}")
        print(f"  语言模型头: {output_params:,}")
        print(f"  总计: {total_params:,} ≈ {total_params / 1e9:.2f}B")

    def print_layer_structure(self):
        """打印层级结构"""
        print("\n" + "=" * 70)
        print("模型层级结构")
        print("=" * 70)

        num_layers = self.config.get('num_hidden_layers', 28)
        hidden_size = self.config.get('hidden_size', 1536)
        num_heads = self.config.get('num_attention_heads', 12)
        intermediate_size = self.config.get('intermediate_size', 8960)
        vocab_size = self.config.get('vocab_size', 151936)

        print(f"\n【输入层】")
        print(f"  └─ embed_tokens: 词嵌入")
        print(f"      输入: token_ids [batch, seq_len]")
        print(f"      输出: embeddings [batch, seq_len, {hidden_size}]")
        print(f"      参数: {vocab_size} × {hidden_size} = {vocab_size * hidden_size:,}")
        print(f"      功能: 将离散token转换为连续向量表示")
        print(f"      作用: 学习每个token的语义，是模型理解的第一步")

        print(f"\n  └─ rotary_emb: 旋转位置编码")
        print(f"      输入: Q, K 向量")
        print(f"      输出: 添加了位置信息的Q, K")
        print(f"      参数: 0 (无参数)")
        print(f"      功能: 通过旋转向量注入位置信息")
        print(f"      优势: 支持任意长度，可外推")

        print(f"\n【Transformer解码器层 (共{num_layers}层)】")
        for i in range(min(2, num_layers)):
            print(f"\n  第 {i} 层:")
            print(f"    ├─ input_layernorm: RMSNorm")
            print(f"        输入: hidden [{hidden_size}]")
            print(f"        输出: normalized [{hidden_size}]")
            print(f"        参数: {hidden_size}")
            print(f"        作用: Pre-norm，稳定注意力输入")

            print(f"\n    ├─ self_attn: 自注意力")
            print(f"        头数: {num_heads}")
            print(f"        每头维度: {hidden_size // num_heads}")
            print(f"        公式: softmax(QK^T/√d)V")
            print(f"        组件:")
            print(f"          ├─ q_proj: [{hidden_size}×{hidden_size}] = {hidden_size*hidden_size:,}")
            print(f"          ├─ k_proj: [{hidden_size}×{hidden_size}] = {hidden_size*hidden_size:,}")
            print(f"          ├─ v_proj: [{hidden_size}×{hidden_size}] = {hidden_size*hidden_size:,}")
            print(f"          └─ o_proj: [{hidden_size}×{hidden_size}] = {hidden_size*hidden_size:,}")
            print(f"        总计: {4*hidden_size*hidden_size:,}")
            print(f"        作用: 捕捉序列长距离依赖")

            print(f"\n    ├─ post_attention_layernorm: RMSNorm")
            print(f"        参数: {hidden_size}")
            print(f"        作用: 稳定MLP输入")

            print(f"\n    └─ mlp: 前馈网络 (SwiGLU)")
            print(f"        激活: SiLU")
            print(f"        公式: (SiLU(xW_g)⊙(xW_u))W_d")
            print(f"        组件:")
            print(f"          ├─ gate_proj: [{hidden_size}×{intermediate_size}] = {hidden_size*intermediate_size:,}")
            print(f"          ├─ up_proj: [{hidden_size}×{intermediate_size}] = {hidden_size*intermediate_size:,}")
            print(f"          └─ down_proj: [{intermediate_size}×{hidden_size}] = {intermediate_size*hidden_size:,}")
            print(f"        总计: {3*hidden_size*intermediate_size:,}")
            print(f"        作用: 提取深层特征")

        if num_layers > 2:
            print(f"\n  ... 剩余 {num_layers - 2} 层结构相同")

        print(f"\n【输出层】")
        print(f"  └─ norm: 最终归一化")
        print(f"      输入: hidden [{hidden_size}]")
        print(f"      输出: normalized [{hidden_size}]")
        print(f"      参数: {hidden_size}")

        print(f"\n  └─ lm_head: 语言模型头")
        print(f"      输入: hidden [batch, seq_len, {hidden_size}]")
        print(f"      输出: logits [batch, seq_len, {vocab_size}]")
        print(f"      参数: {vocab_size} × {hidden_size} = {vocab_size * hidden_size:,}")
        print(f"      功能: 预测下一个token")
        print(f"      注意: 通常与embed_tokens共享权重")

    def print_data_flow(self):
        """打印数据流"""
        print("\n" + "=" * 70)
        print("模型数据流详解")
        print("=" * 70)

        num_layers = self.config.get('num_hidden_layers', 28)
        hidden_size = self.config.get('hidden_size', 1536)
        vocab_size = self.config.get('vocab_size', 151936)

        data_flow = """
【完整数据流程】

Step 1: 输入
  ┌─────────────────────────────────────────┐
  │ 输入文本 → Tokenizer → Token IDs       │
  │ 示例: "Hello world" → [15496, 2159]    │
  └─────────────────────────────────────────┘
           ↓
  形状: [batch_size, seq_len]
  ┌─────────────────────────────────────────┐
  │ 例如: [1, 6]                             │
  └─────────────────────────────────────────┘

           ↓
Step 2: 词嵌入
  ┌─────────────────────────────────────────┐
  │ Embedding Lookup                        │
  │ embeddings = W[token_id]                │
  └─────────────────────────────────────────┘
           ↓
  形状: [batch, seq_len, {hidden_size}]
  ┌─────────────────────────────────────────┐
  │ 例如: [1, 6, {hidden_size}]              │
  └─────────────────────────────────────────┘
  说明: 每个token映射为{hidden_size}维向量

           ↓
Step 3: 位置编码
  ┌─────────────────────────────────────────┐
  │ RoPE (Rotary Position Embedding)         │
  │ 对Q和K向量应用旋转                        │
  │ 注入相对位置信息                          │
  └─────────────────────────────────────────┘
  形状不变: [batch, seq_len, {hidden_size}]

           ↓
Step 4: Transformer层 (重复{num_layers}次)
  ┌─────────────────────────────────────────┐
  │ 每层包含:                                │
  │                                         │
  │  4.1 Input RMSNorm                      │
  │      x̂ = x * γ / √(mean(x²) + ε)        │
  │                                         │
  │  4.2 Self-Attention                    │
  │      Q = x @ W_q                        │
  │      K = x @ W_k                        │
  │      V = x @ W_v                        │
  │      A = softmax(QK^T/√d) @ V           │
  │      x = A @ W_o                        │
  │                                         │
  │  4.3 Post-Attention RMSNorm            │
  │      x̂ = x * γ / √(mean(x²) + ε)        │
  │                                         │
  │  4.4 MLP (SwiGLU)                       │
  │      gate = SiLU(x @ W_gate)            │
  │      up = x @ W_up                      │
  │      x = (gate ⊙ up) @ W_down           │
  └─────────────────────────────────────────┘
  每层输入输出形状: [batch, seq_len, {hidden_size}]

           ↓
Step 5: 最终归一化
  ┌─────────────────────────────────────────┐
  │ Final RMSNorm                            │
  │ x̂ = x * γ / √(mean(x²) + ε)            │
  └─────────────────────────────────────────┘
  形状: [batch, seq_len, {hidden_size}]

           ↓
Step 6: 语言模型头
  ┌─────────────────────────────────────────┐
  │ LM Head                                  │
  │ logits = x @ W_lm_head                  │
  └─────────────────────────────────────────┘
           ↓
  形状: [batch, seq_len, {vocab_size}]
  ┌─────────────────────────────────────────┐
  │ 例如: [1, 6, {vocab_size}]               │
  └─────────────────────────────────────────┘
  说明: 每个位置预测{vocab_size}个token的logits

           ↓
Step 7: 下一个token预测
  ┌─────────────────────────────────────────┐
  │ probabilities = softmax(logits[:, -1]) │
  │ next_token = sample(probabilities)      │
  └─────────────────────────────────────────┘

【关键机制说明】

1. 因果掩码 (Causal Mask)
   - 确保每个token只能看到之前的信息
   - 在注意力分数计算时应用
   - 保持自回归特性

2. 残差连接 (Residual Connection)
   - x = LayerNorm(x + Sublayer(x))
   - 缓解梯度消失
   - 支持深层网络训练

3. Pre-norm架构
   - 归一化在子层之前
   - 相比Post-norm更稳定
   - Qwen采用Pre-norm

4. KV Cache (推理优化)
   - 缓存历史token的K和V
   - 生成时只需计算新token
   - 加速自回归生成

【训练 vs 推理】

训练阶段:
  - 一次前向传播处理完整序列
  - 并行计算所有位置
  - 使用teacher forcing

推理阶段:
  - 自回归生成一个token
  - 每次只计算新token
  - 使用KV Cache优化
        """.format(
            hidden_size=hidden_size,
            vocab_size=vocab_size,
            num_layers=num_layers
        )

        print(data_flow)

    def print_module_functionality(self):
        """打印模块功能说明"""
        print("\n" + "=" * 70)
        print("模块功能详细说明")
        print("=" * 70)

        for module_key, module_info in self.module_functionality.items():
            print(f"\n【{module_key}】")
            print(f"  中文名: {module_info.get('chinese_name', 'N/A')}")
            print(f"  描述: {module_info.get('description', 'N/A')}")

            if 'input' in module_info:
                print(f"  输入: {module_info['input']}")
            if 'output' in module_info:
                print(f"  输出: {module_info['output']}")
            if 'formula' in module_info:
                print(f"  公式: {module_info['formula']}")
            if 'role' in module_info:
                print(f"  作用: {module_info['role']}")
            if 'purpose' in module_info:
                print(f"  目的: {module_info['purpose']}")

            if 'key_points' in module_info:
                print(f"  关键点:")
                for point in module_info['key_points']:
                    print(f"    • {point}")

            if 'advantages' in module_info:
                print(f"  优势:")
                for adv in module_info['advantages']:
                    print(f"    • {adv}")

            if 'in_qwen' in module_info:
                print(f"  在Qwen中的实现: {module_info['in_qwen']}")

    def print_architecture_explanation(self):
        """打印架构详细解释"""
        print("\n" + "=" * 70)
        print("Qwen2.5 架构深度解析")
        print("=" * 70)

        architecture = """
【Qwen2.5 架构设计理念】

Qwen2.5采用现代Transformer Decoder架构，整合了多项技术创新。

【核心技术组件解析】

1. 多头自注意力机制 (Multi-Head Self-Attention)

   概念:
   - 将隐藏维度分为多个头，每个头独立学习不同的关系模式
   - 每个头专注于不同类型的信息（如句法、语义、指代等）

   工作流程:
   a. 投影: 输入通过Q/K/V/O四个线性层
   b. 缩放点积注意力: 计算查询和键的相关性
   c. 多头拼接: 将各头的输出拼接
   d. 融合: 通过O投影融合多头信息

   在Qwen中的作用:
   - 捕捉长距离依赖关系
   - 理解上下文关系
   - 处理指代消解等复杂语言现象

2. SwiGLU 前馈网络

   概念:
   - 门控线性单元（GLU）的改进版本
   - 使用SiLU激活函数
   - 公式: SwiGLU(x) = (SiLU(xW₁) ⊙ (xW₂))W₃

   与传统MLP对比:
   传统: MLP(x) = ReLU(xW₁)W₂
   SwiGLU: MLP(x) = (SiLU(xW₁) ⊙ xW₂)W₃

   优势:
   - 门控机制动态控制信息流
   - 更好的梯度流动
   - 更高的参数效率
   - 在大模型中表现优异

   在Qwen中的作用:
   - 提取深层语义特征
   - 增加模型非线性能力
   - 实现复杂模式识别

3. RMSNorm 归一化

   概念:
   - 均方根层归一化
   - 相比LayerNorm更简单高效
   - 公式: RMSNorm(x) = x * γ / √(mean(x²) + ε)

   与LayerNorm对比:
   LayerNorm: (x - μ) / σ * γ + β
   RMSNorm: x / RMS(x) * γ

   优势:
   - 无需计算均值（节省计算）
   - 无可学习偏置（节省参数）
   - 训练稳定性更好
   - 在Transformer中表现优异

   在Qwen中的作用:
   - 稳定层间分布
   - 加速训练收敛
   - 防止梯度爆炸/消失

4. RoPE 旋转位置编码

   概念:
   - 通过旋转向量注入位置信息
   - 相对位置编码，不是绝对位置
   - 基于复数旋转的几何直观

   工作原理:
   - 对Q和K向量应用旋转矩阵
   - 不同位置应用不同角度的旋转
   - 相对位置信息通过旋转差体现

   公式:
   pos = m, dim = 2i (偶数维度)
   freq = m * θ^(-2i/d)
   q'_i = q_i * cos(freq) - q_{i+1} * sin(freq)
   q'_{i+1} = q_i * sin(freq) + q_{i+1} * cos(freq)

   优势:
   - 可外推到训练长度之外
   - 支持任意长度序列
   - 位置信息可插拔
   - 长文本任务表现优异

   在Qwen中的作用:
   - 理解token的相对位置
   - 处理可变长度输入
   - 支持长文档理解

5. Pre-norm 架构

   概念:
   - 归一化在子层之前（而非之后）
   - ResNet风格的残差连接

   架构对比:
   Post-norm: Sublayer(LayerNorm(x)) + x
   Pre-norm: LayerNorm(x) + Sublayer(x)

   优势:
   - 梯度流动更顺畅
   - 深层网络训练更稳定
   - 支持更多层
   - 收敛速度更快

   在Qwen中的应用:
   - 每层两个Pre-norm位置
   - 输入和后注意力归一化

【模型训练流程】

阶段1: 预训练
  ├─ 数据: 万亿级token的混合语料
  ├─ 任务: 下一个token预测
  ├─ 目标: 学习通用的语言知识
  ├─ 时长: 数周到数月
  └─ 结果: 基础语言模型

阶段2: 指令微调
  ├─ 数据: 人工标注的指令-响应对
  ├─ 任务: 遵循用户指令
  ├─ 格式: 对话式训练数据
  └─ 结果: 有用的对话模型

阶段3: 对齐优化
  ├─ 方法: RLHF (强化学习) 或 DPO (直接偏好优化)
  ├─ 目标: 符合人类偏好
  ├─ 约束: 有用性、安全性、诚实性
  └─ 结果: 对齐的智能助手

【推理优化技术】

1. KV Cache
   - 缓存历史token的K和V
   - 避免重复计算
   - 显存换时间

2. Flash Attention
   - 分块计算注意力
   - 减少内存访问
   - 提高速度

3. 量化
   - 降低精度 (FP16 → INT8/INT4)
   - 减少显存占用
   - 保持性能

4. 权重共享
   - embed_tokens与lm_head共享
   - 节省参数
   - 稳定训练

【Qwen2.5的特色】

1. 多语言能力
   - 优化中文理解生成
   - 兼顾英文等其他语言
   - 跨语言迁移能力

2. 指令遵循
   - 精细的指令微调
   - 复杂任务理解
   - 格式要求遵循

3. 代码能力
   - 代码生成和理解
   - 多种编程语言
   - 调试和优化

4. 长文本处理
   - RoPE支持长序列
   - 长文档理解
   - 长上下文记忆

5. 推理能力
   - 逻辑推理
   - 数学计算
   - 知识问答
        """

        print(architecture)

    def print_generation_config(self):
        """打印生成配置"""
        print("\n" + "=" * 70)
        print("生成配置参数")
        print("=" * 70)

        print("\n【生成策略】")
        for key, value in self.generation_config.items():
            print(f"  {key}: {value}")

    def export_analysis_report(self, output_file: str = "qwen_model_analysis_report.md"):
        """导出分析报告"""
        print(f"\n正在导出完整分析报告到 {output_file}...")

        with open(output_file, "w", encoding="utf-8") as f:
            f.write("# Qwen2.5-1.5B 模型结构分析报告\n\n")
            f.write("---\n\n")

            # 基本信息
            f.write("## 1. 模型概览\n\n")
            f.write(f"- **模型名称**: Qwen2.5-1.5B-Instruct\n")
            f.write(f"- **模型类型**: {self.config.get('model_type', 'Qwen2ForCausalLM')}\n")
            f.write(f"- **架构**: Transformer Decoder\n\n")

            # 配置信息
            f.write("## 2. 配置参数\n\n")
            f.write("| 参数 | 值 | 说明 |\n")
            f.write("|------|-----|------|\n")
            f.write(f"| 词表大小 | {self.config.get('vocab_size')} | 模型可识别的token数量 |\n")
            f.write(f"| 隐藏层维度 | {self.config.get('hidden_size')} | 模型的内部表示维度 |\n")
            f.write(f"| Transformer层数 | {self.config.get('num_hidden_layers')} | 堆叠的解码器层数 |\n")
            f.write(f"| 注意力头数 | {self.config.get('num_attention_heads')} | 多头注意力的头数 |\n")
            f.write(f"| 中间层维度 | {self.config.get('intermediate_size')} | MLP层的扩展维度 |\n")
            f.write(f"| 最大序列长度 | {self.config.get('max_position_embeddings', 'N/A')} | 模型支持的最大输入长度 |\n\n")

            # 层级结构
            f.write("## 3. 模型层级结构\n\n")
            f.write("### 3.1 输入层\n\n")
            f.write("```\n")
            f.write("├─ embed_tokens: 词嵌入\n")
            f.write("│   ├─ 输入: token_ids [batch, seq_len]\n")
            f.write("│   ├─ 输出: embeddings [batch, seq_len, hidden_size]\n")
            f.write("│   └─ 作用: 将离散token转换为连续向量\n")
            f.write("│\n")
            f.write("└─ rotary_emb: 旋转位置编码\n")
            f.write("    ├─ 输入: Q, K 向量\n")
            f.write("    ├─ 输出: 添加位置信息的Q, K\n")
            f.write("    └─ 作用: 注入相对位置信息\n")
            f.write("```\n\n")

            f.write("### 3.2 Transformer层\n\n")
            f.write("每层包含以下组件：\n\n")
            f.write("```\n")
            f.write("├─ input_layernorm: RMSNorm\n")
            f.write("│   └─ 作用: Pre-norm，稳定注意力输入\n")
            f.write("│\n")
            f.write("├─ self_attn: 自注意力\n")
            f.write("│   ├─ q_proj: 查询投影\n")
            f.write("│   ├─ k_proj: 键投影\n")
            f.write("│   ├─ v_proj: 值投影\n")
            f.write("│   ├─ o_proj: 输出投影\n")
            f.write("│   └─ 公式: softmax(QK^T/√d)V\n")
            f.write("│\n")
            f.write("├─ post_attention_layernorm: RMSNorm\n")
            f.write("│   └─ 作用: 稳定MLP输入\n")
            f.write("│\n")
            f.write("└─ mlp: 前馈网络\n")
            f.write("    ├─ gate_proj: 门控投影\n")
            f.write("    ├─ up_proj: 上投影\n")
            f.write("    ├─ down_proj: 下投影\n")
            f.write("    └─ 激活: SiLU (SwGLU)\n")
            f.write("```\n\n")

            # 模块功能
            f.write("## 4. 模块功能详解\n\n")
            for module_key, module_info in self.module_functionality.items():
                f.write(f"### {module_key}\n\n")
                f.write(f"- **中文名**: {module_info.get('chinese_name', 'N/A')}\n")
                f.write(f"- **描述**: {module_info.get('description', 'N/A')}\n")
                if 'formula' in module_info:
                    f.write(f"- **公式**: `{module_info['formula']}`\n")
                if 'role' in module_info:
                    f.write(f"- **作用**: {module_info['role']}\n")
                f.write("\n")

        print(f"✓ 分析报告已导出到 {output_file}")

    def run_full_analysis(self):
        """运行完整分析"""
        self.load_configs()
        self.print_basic_info()
        self.print_layer_structure()
        self.print_data_flow()
        self.print_module_functionality()
        self.print_architecture_explanation()
        self.print_generation_config()
        self.export_analysis_report()

        print("\n" + "=" * 70)
        print("✓ Qwen2.5-1.5B 模型分析完成！")
        print("=" * 70)


def main():
    """主函数"""
    analyzer = QuickQwenAnalyzer(MODEL_PATH)
    analyzer.run_full_analysis()


if __name__ == "__main__":
    main()
