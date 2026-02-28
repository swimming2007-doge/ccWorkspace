"""
Qwen 模型资源消耗详细分析脚本
分析每个步骤的算力（FLOPs）、内存和访存带宽需求
"""

import os
import sys
import json
from typing import Dict, Any, Tuple, List

# 修复Windows编码问题
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# 模型路径
MODEL_PATH = r"C:\Users\Administrator\.cache\modelscope\hub\models\Qwen\Qwen2___5-1___5B-Instruct"


class ResourceCalculator:
    """资源计算器 - 计算FLOPs、内存和带宽"""

    def __init__(self, config: Dict):
        self.config = config
        self.vocab_size = config.get('vocab_size', 151936)
        self.hidden_size = config.get('hidden_size', 1536)
        self.num_layers = config.get('num_hidden_layers', 28)
        self.num_heads = config.get('num_attention_heads', 12)
        self.head_dim = self.hidden_size // self.num_heads
        self.intermediate_size = config.get('intermediate_size', 8960)
        self.max_seq_len = config.get('max_position_embeddings', 32768)

        # 数据类型大小（字节）
        self.dtype_size = 2  # FP16 = 2 bytes
        self.int_size = 4    # int32 = 4 bytes

    def matrix_mul_flops(self, M: int, N: int, K: int) -> int:
        """
        计算矩阵乘法的FLOPs
        输入: A[M,K] @ B[K,N] = C[M,N]
        复杂度: 2*M*N*K (M*K次乘法 + M*K次加法)

        依据:
        - 矩阵乘法C[i,j] = sum_k(A[i,k] * B[k,j])
        - 每个元素需要K次乘法和K-1次加法
        - 简化为2*M*N*K FLOPs
        """
        return 2 * M * N * K

    def attention_flops(self, seq_len: int) -> Dict[str, int]:
        """
        计算自注意力的FLOPs

        注意力机制步骤:
        1. Q, K, V 投影: 3 * hidden_size * hidden_size * seq_len
        2. 注意力分数计算: seq_len * seq_len * head_dim * num_heads
        3. Softmax: seq_len * seq_len * num_heads (指数、求和、除法)
        4. 加权求和: seq_len * seq_len * head_dim * num_heads
        5. 输出投影: hidden_size * hidden_size * seq_len

        依据:
        - Self-Attention in Transformers: "Attention is All You Need" (2017)
        - Flash Attention优化后的复杂度: 4 * seq_len * seq_len * hidden_size
        """
        # Q, K, V投影
        qkv_flops = 3 * self.matrix_mul_flops(seq_len, self.hidden_size, self.hidden_size)

        # 注意力分数 Q @ K^T
        attn_scores_flops = self.matrix_mul_flops(seq_len, seq_len, self.hidden_size)

        # Softmax (简化为 seq_len^2 * num_heads，每个位置的归一化)
        softmax_flops = seq_len * seq_len * self.num_heads * 3  # exp, sum, div

        # 加权求和 Attn @ V
        weighted_sum_flops = self.matrix_mul_flops(seq_len, self.head_dim, seq_len) * self.num_heads

        # 输出投影 O
        output_flops = self.matrix_mul_flops(seq_len, self.hidden_size, self.hidden_size)

        total = qkv_flops + attn_scores_flops + softmax_flops + weighted_sum_flops + output_flops

        return {
            'qkv_projection': qkv_flops,
            'attention_scores': attn_scores_flops,
            'softmax': softmax_flops,
            'weighted_sum': weighted_sum_flops,
            'output_projection': output_flops,
            'total': total
        }

    def mlp_flops(self, seq_len: int) -> Dict[str, int]:
        """
        计算MLP (SwiGLU) 的FLOPs

        SwiGLU步骤:
        1. Gate投影: seq_len * intermediate_size * hidden_size
        2. SiLU激活: seq_len * intermediate_size (约3次浮点运算)
        3. Up投影: seq_len * intermediate_size * hidden_size
        4. 元素乘积: seq_len * intermediate_size
        5. Down投影: seq_len * hidden_size * intermediate_size

        依据:
        - SwiGLU: (SiLU(xW_g) ⊙ (xW_u)) W_d
        - SiLU(x) ≈ x * sigmoid(x)，需要约3 FLOPs
        """
        # Gate投影
        gate_flops = self.matrix_mul_flops(seq_len, self.intermediate_size, self.hidden_size)

        # Up投影
        up_flops = self.matrix_mul_flops(seq_len, self.intermediate_size, self.hidden_size)

        # SiLU激活 (约3 FLOPs per element)
        silu_flops = seq_len * self.intermediate_size * 3

        # 元素乘积
        elementwise_flops = seq_len * self.intermediate_size

        # Down投影
        down_flops = self.matrix_mul_flops(seq_len, self.hidden_size, self.intermediate_size)

        total = gate_flops + up_flops + silu_flops + elementwise_flops + down_flops

        return {
            'gate_projection': gate_flops,
            'up_projection': up_flops,
            'silu_activation': silu_flops,
            'elementwise_mul': elementwise_flops,
            'down_projection': down_flops,
            'total': total
        }

    def layernorm_flops(self, seq_len: int) -> int:
        """
        计算RMSNorm的FLOPs

        RMSNorm步骤:
        1. 计算平方: seq_len * hidden_size
        2. 求平均: seq_len * hidden_size
        3. 平方根: hidden_size
        4. 除法和乘法: seq_len * hidden_size * 2

        依据:
        - RMSNorm(x) = x * γ / sqrt(mean(x²) + ε)
        - 比LayerNorm更简单，无需计算均值和中心化
        """
        return seq_len * self.hidden_size * 5  # 简化估算

    def embedding_flops(self, seq_len: int) -> int:
        """
        计算词嵌入的FLOPs

        嵌入查找本质上是查表，FLOPs为0
        但这里计算输出激活的FLOPs
        """
        return 0  # 查表操作，无计算

    def layer_memory(self, seq_len: int, batch_size: int = 1) -> Dict[str, int]:
        """
        计算单层的内存需求（字节）

        包含:
        1. 输入激活: batch * seq_len * hidden_size * dtype
        2. 输出激活: batch * seq_len * hidden_size * dtype
        3. Q, K, V中间结果
        4. 注意力分数矩阵 (seq_len * seq_len)
        5. MLP中间结果
        """
        dtype = self.dtype_size

        # 输入/输出激活
        activation_size = batch_size * seq_len * self.hidden_size * dtype

        # Q, K, V
        qkv_size = 3 * batch_size * self.num_heads * seq_len * self.head_dim * dtype

        # 注意力分数矩阵 (关键！)
        # 使用因果掩码后，有效元素为 seq_len * (seq_len + 1) / 2
        attn_scores_size = batch_size * self.num_heads * (seq_len * (seq_len + 1) // 2) * dtype

        # MLP中间结果
        mlp_intermediate = batch_size * seq_len * self.intermediate_size * dtype

        # KV Cache (推理时累积)
        kv_cache_size = 2 * batch_size * self.num_layers * seq_len * self.head_dim * self.num_heads * dtype

        return {
            'activation': activation_size,
            'qkv': qkv_size,
            'attention_scores': attn_scores_size,
            'mlp_intermediate': mlp_intermediate,
            'kv_cache': kv_cache_size,
            'total_per_layer': activation_size * 2 + qkv_size + attn_scores_size + mlp_intermediate
        }

    def memory_access(self, seq_len: int, batch_size: int = 1) -> Dict[str, int]:
        """
        计算内存访问量（字节）

        每个操作需要:
        - 读输入
        - 读权重
        - 写输出

        依据:
        - Roofline Model: 计算受限于内存带宽时，性能 = 带宽 / 算术强度
        - 算术强度 = FLOPs / 内存访问量(字节)
        """
        dtype = self.dtype_size
        int_size = self.int_size

        # 注意力
        # 读: 输入(3次) + 权重(3次 Q/K/V/O) + 注意力分数 + V
        # 写: Q, K, V, O
        attn_read = (
            batch_size * seq_len * self.hidden_size * dtype * 3 +  # 输入读
            self.hidden_size * self.hidden_size * dtype * 4 +       # 权重读
            batch_size * seq_len * seq_len * dtype * 2 +         # 注意力分数
            batch_size * seq_len * self.head_dim * dtype          # V读
        )
        attn_write = (
            batch_size * self.num_heads * seq_len * self.head_dim * dtype * 4  # Q,K,V,O写
        )
        attn_access = attn_read + attn_write

        # MLP
        # 读: 输入(2次) + 权重(3次)
        # 写: gate, up, output
        mlp_read = (
            batch_size * seq_len * self.hidden_size * dtype * 2 +      # 输入读
            self.hidden_size * self.intermediate_size * dtype * 3     # 权重读
        )
        mlp_write = (
            batch_size * seq_len * self.intermediate_size * dtype * 3  # gate, up, down
        )
        mlp_access = mlp_read + mlp_write

        # 归一化
        # 读: 输入 + 权重
        # 写: 输出
        norm_read = batch_size * seq_len * self.hidden_size * dtype * 2
        norm_write = batch_size * seq_len * self.hidden_size * dtype

        return {
            'attention': attn_access,
            'mlp': mlp_access,
            'normalization': norm_read + norm_write,
            'total': attn_access + mlp_access + norm_read + norm_write
        }


class ResourceAnalyzer:
    """资源分析器 - 全面分析模型资源消耗"""

    def __init__(self, model_path: str):
        self.model_path = model_path
        self.config = None
        self.calc = None

    def load_config(self):
        """加载模型配置"""
        print("=" * 80)
        print("加载 Qwen2.5-1.5B 模型配置...")
        print("=" * 80)

        config_path = os.path.join(self.model_path, "config.json")
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = json.load(f)

        self.calc = ResourceCalculator(self.config)

        print("✓ 配置加载成功")
        print(f"  词表大小: {self.config.get('vocab_size')}")
        print(f"  隐藏维度: {self.config.get('hidden_size')}")
        print(f"  层数: {self.config.get('num_hidden_layers')}")
        print(f"  注意力头: {self.config.get('num_attention_heads')}")

    def print_analysis_basis(self):
        """打印分析依据"""
        print("\n" + "=" * 80)
        print("分析依据和方法论")
        print("=" * 80)

        basis = """
【FLOPs计算依据】

1. 矩阵乘法 (GEMM)
   - 复杂度: 2 * M * N * K
   - 公式: C = A @ B，其中 A[M,K], B[K,N], C[M,N]
   - 每个元素 C[i,j] = Σ_k A[i,k] * B[k,j]
   - 需要 K 次乘法和 K-1 次加法 ≈ 2K FLOPs
   - 总计: M * N * 2K = 2MNK FLOPs
   - 参考文献: High Performance Matrix Multiplication (Goto et al.)

2. 自注意力机制
   - Q, K, V投影: 3 * hidden_size^2 * seq_len
   - 注意力分数: seq_len^2 * hidden_size
   - Softmax: seq_len^2 * num_heads * 3 (exp, sum, div)
   - 加权求和: seq_len^2 * head_dim * num_heads
   - 输出投影: hidden_size^2 * seq_len
   - 总计: ~4 * seq_len^2 * hidden_size
   - 参考文献: "Attention Is All You Need" (Vaswani et al., 2017)

3. MLP (SwiGLU)
   - Gate投影: hidden_size * intermediate_size * seq_len
   - Up投影: hidden_size * intermediate_size * seq_len
   - SiLU激活: 3 * intermediate_size * seq_len
   - 元素乘积: intermediate_size * seq_len
   - Down投影: intermediate_size * hidden_size * seq_len
   - 参考文献: "GLU Variants Improve Transformer" (Shazeer, 2020)

4. RMSNorm
   - 公式: x̂ = x * γ / sqrt(mean(x²) + ε)
   - 每个元素: 5 FLOPs (平方、求和、开方、除法、乘法)
   - 参考文献: "Root Mean Square Layer Normalization" (Zhang & Sennrich, 2019)

【内存计算依据】

1. 激活内存
   - 大小: batch_size * seq_len * hidden_size * dtype_size
   - FP16: 2 bytes per element
   - 每层需要存储输入和输出激活

2. 注意力分数矩阵
   - 大小: batch_size * num_heads * seq_len^2
   - 使用因果掩码后有效元素: seq_len * (seq_len + 1) / 2
   - 这是Transformer的主要内存瓶颈

3. KV Cache
   - 推理时缓存历史token的K和V
   - 大小: 2 * batch * num_layers * seq_len * head_dim * num_heads
   - 累积增长，seq_len是生成的token总数

【访存带宽计算依据】

1. Roofline模型
   - 算术强度 (AI) = FLOPs / 字节访问
   - 受限情况:
     * AI < 设备AI: 内存受限
     * AI > 设备AI: 计算受限
   - 参考文献: "Roofline Model" (Williams et al., 2009)

2. 内存访问量
   - 矩阵乘法: 读输入 + 读权重 + 写输出
   - 注意力: 额外需要读写注意力分数矩阵
   - MLP: 读写中间激活

3. 带宽需求
   - 最小带宽 = 总内存访问 / 最大可容忍延迟
   - 理想带宽 = 总内存访问 / 计算时间
   - GPU典型带宽: 300-2000 GB/s (A100: 1935 GB/s)

【假设条件】

1. 数据类型: FP16 (2 bytes)
2. Batch size: 1 (单样本推理)
3. 序列长度: 可变 (分析不同长度)
4. 精度: 估算值，实际可能有10-20%误差
5. 优化: 未考虑Flash Attention等优化技术
        """

        print(basis)

    def analyze_flops(self, seq_lengths: List[int]):
        """分析不同序列长度的FLOPs"""
        print("\n" + "=" * 80)
        print("FLOPs (浮点运算) 分析")
        print("=" * 80)

        print(f"\n【不同序列长度的FLOPs】")
        print(f"批次大小: 1")
        print(f"{'序列长度':<12} {'注意力(每层)':<18} {'MLP(每层)':<18} {'总FLOPs(每层)':<18} {'总FLOPs({}层)':<18}".format(self.calc.num_layers))
        print("-" * 84)

        for seq_len in seq_lengths:
            attn_flops = self.calc.attention_flops(seq_len)
            mlp_flops = self.calc.mlp_flops(seq_len)
            norm_flops = 2 * self.calc.layernorm_flops(seq_len)  # 两个归一化

            layer_total = attn_flops['total'] + mlp_flops['total'] + norm_flops
            total = layer_total * self.calc.num_layers + self.calc.embedding_flops(seq_len) * 2

            print(f"{seq_len:<12} {attn_flops['total']:>16,} {mlp_flops['total']:>16,} {layer_total:>16,} {total:>16,}")

        # 详细分解（以2048序列长度为例）
        seq_len = 2048
        print(f"\n【单层FLOPs详细分解 (seq_len={seq_len})】")
        print("-" * 80)

        print("\n1. 自注意力层")
        attn = self.calc.attention_flops(seq_len)
        for key, value in attn.items():
            if key != 'total':
                percentage = value / attn['total'] * 100
                print(f"  {key:20s}: {value:>15,} FLOPs ({percentage:>5.1f}%)")
        print(f"  {'总计':20s}: {attn['total']:>15,} FLOPs")

        print("\n2. MLP层 (SwiGLU)")
        mlp = self.calc.mlp_flops(seq_len)
        for key, value in mlp.items():
            if key != 'total':
                percentage = value / mlp['total'] * 100
                print(f"  {key:20s}: {value:>15,} FLOPs ({percentage:>5.1f}%)")
        print(f"  {'总计':20s}: {mlp['total']:>15,} FLOPs")

        print("\n3. 归一化层")
        norm = 2 * self.calc.layernorm_flops(seq_len)
        print(f"  {'RMSNorm × 2':20s}: {norm:>15,} FLOPs")

        layer_total = attn['total'] + mlp['total'] + norm
        print(f"\n{'单层总计':20s}: {layer_total:>15,} FLOPs")

        # 比例分析
        print(f"\n【组件FLOPs占比】")
        print(f"  自注意力: {attn['total'] / layer_total * 100:>5.1f}%")
        print(f"  MLP: {mlp['total'] / layer_total * 100:>5.1f}%")
        print(f"  归一化: {norm / layer_total * 100:>5.1f}%")

    def analyze_memory(self, seq_lengths: List[int]):
        """分析内存需求"""
        print("\n" + "=" * 80)
        print("内存需求分析")
        print("=" * 80)

        print(f"\n【单层内存需求 (batch_size=1)】")
        print(f"{'序列长度':<12} {'激活':<15} {'注意力分数':<15} {'KV Cache':<15} {'总计':<15}")
        print("-" * 72)

        for seq_len in seq_lengths:
            mem = self.calc.layer_memory(seq_len)
            print(f"{seq_len:<12} {mem['activation']/1024**2:>10.1f} MB {mem['attention_scores']/1024**2:>10.1f} MB "
                  f"{mem['kv_cache']/1024**2:>10.1f} MB {mem['total_per_layer']/1024**2:>10.1f} MB")

        # 详细的内存分解
        seq_len = 2048
        print(f"\n【内存详细分解 (seq_len={seq_len}, batch_size=1)】")
        print("-" * 80)

        mem = self.calc.layer_memory(seq_len)
        print(f"\n1. 激活内存")
        print(f"  输入/输出: {mem['activation']/1024**2:>10.1f} MB")
        print(f"    计算: {1} × {seq_len} × {self.calc.hidden_size} × {self.calc.dtype_size} bytes")
        print(f"          = {mem['activation']:,} bytes = {mem['activation']/1024**2:.1f} MB")

        print(f"\n2. 注意力分数矩阵")
        print(f"  大小: {mem['attention_scores']/1024**2:>10.1f} MB")
        print(f"    计算: {1} × {self.calc.num_heads} × ({seq_len}×{seq_len}/2) × {self.calc.dtype_size} bytes")
        print(f"          = {mem['attention_scores']:,} bytes = {mem['attention_scores']/1024**2:.1f} MB")
        print(f"    说明: 因果掩码后有效元素为 seq_len×(seq_len+1)/2")

        print(f"\n3. KV Cache (推理时累积)")
        print(f"  大小: {mem['kv_cache']/1024**2:>10.1f} MB")
        print(f"    计算: 2 × {self.calc.num_layers} × {seq_len} × {self.calc.head_dim} × {self.calc.num_heads} × {self.calc.dtype_size} bytes")
        print(f"          = {mem['kv_cache']:,} bytes = {mem['kv_cache']/1024**2:.1f} MB")

        print(f"\n4. MLP中间结果")
        print(f"  大小: {mem['mlp_intermediate']/1024**2:>10.1f} MB")
        print(f"    计算: {1} × {seq_len} × {self.calc.intermediate_size} × {self.calc.dtype_size} bytes")

        # 完整模型内存
        print(f"\n【完整模型推理内存】")

        # 参数内存
        total_params = (
            self.calc.vocab_size * self.calc.hidden_size +  # embed
            self.calc.vocab_size * self.calc.hidden_size +  # lm_head
            self.calc.num_layers * 2 * self.calc.hidden_size +  # norms
            self.calc.num_layers * 4 * self.calc.hidden_size * self.calc.hidden_size +  # attn
            self.calc.num_layers * 3 * self.calc.hidden_size * self.calc.intermediate_size  # mlp
        )
        param_memory = total_params * self.calc.dtype_size

        print(f"\n1. 模型参数")
        print(f"  总参数: {total_params:,}")
        print(f"  内存: {param_memory/1024**3:.2f} GB")

        print(f"\n2. 推理时总内存 (seq_len={seq_len})")
        total_inference_mem = param_memory + mem['total_per_layer'] * self.calc.num_layers
        print(f"  模型参数: {param_memory/1024**3:>10.2f} GB ({param_memory/total_inference_mem*100:>5.1f}%)")
        print(f"  激活内存: {mem['total_per_layer'] * self.calc.num_layers / 1024**3:>10.2f} GB ({mem['total_per_layer'] * self.calc.num_layers / total_inference_mem * 100:>5.1f}%)")
        print(f"  总计: {total_inference_mem/1024**3:>10.2f} GB")

    def analyze_bandwidth(self, seq_lengths: List[int]):
        """分析访存带宽需求"""
        print("\n" + "=" * 80)
        print("访存带宽需求分析")
        print("=" * 80)

        print(f"\n【单层内存访问量 (batch_size=1)】")
        print(f"{'序列长度':<12} {'注意力':<18} {'MLP':<18} {'归一化':<18} {'总计':<18}")
        print("-" * 84)

        for seq_len in seq_lengths:
            access = self.calc.memory_access(seq_len)
            print(f"{seq_len:<12} {access['attention']/1024**2:>12.1f} MB "
                  f"{access['mlp']/1024**2:>12.1f} MB {access['normalization']/1024**2:>12.1f} MB "
                  f"{access['total']/1024**2:>12.1f} MB")

        # 算术强度
        print(f"\n【算术强度分析 (Arithmetic Intensity)】")
        print("算术强度 = FLOPs / 字节访问")
        print("AI < 设备AI: 内存受限 | AI > 设备AI: 计算受限")
        print("-" * 80)

        print(f"\n{'序列长度':<12} {'FLOPs(每层)':<18} {'内存访问(每层)':<18} {'算术强度':<18} {'受限类型':<15}")
        print("-" * 80)

        for seq_len in [512, 1024, 2048, 4096]:
            attn_flops = self.calc.attention_flops(seq_len)['total']
            mlp_flops = self.calc.mlp_flops(seq_len)['total']
            norm_flops = 2 * self.calc.layernorm_flops(seq_len)
            total_flops = attn_flops + mlp_flops + norm_flops

            access = self.calc.memory_access(seq_len)['total']
            ai = total_flops / access  # FLOPs per byte

            # 典型设备AI (FP16)
            # A100: ~300 FLOPs/byte
            # RTX 3090: ~100 FLOPs/byte
            if ai < 100:
                limited = "内存受限"
            elif ai < 300:
                limited = "混合"
            else:
                limited = "计算受限"

            print(f"{seq_len:<12} {total_flops:>16,} {access:>16,} bytes {ai:>16.2f} {limited:>15}")

        # 带宽需求估算
        print(f"\n【带宽需求估算】")
        print(f"假设: FP16精度，单批次推理")

        seq_len = 2048
        access = self.calc.memory_access(seq_len)['total']
        flops = (
            self.calc.attention_flops(seq_len)['total'] +
            self.calc.mlp_flops(seq_len)['total'] +
            2 * self.calc.layernorm_flops(seq_len)
        )
        total_flops = flops * self.calc.num_layers

        print(f"\n单层 (seq_len={seq_len}):")
        print(f"  FLOPs: {flops:,}")
        print(f"  内存访问: {access/1024**2:.1f} MB")
        print(f"  算术强度: {flops/access:.2f} FLOPs/byte")

        # 不同延迟下的带宽需求
        print(f"\n不同延迟下的带宽需求:")
        delays = [1, 5, 10, 50]  # ms
        print(f"{'延迟':<10} {'所需带宽':<20} {'说明'}")
        print("-" * 60)
        for delay in delays:
            bandwidth = access / 1024**3 / (delay / 1000)  # GB/s
            print(f"{delay:<10} {bandwidth:>15.2f} GB/s   延迟{delay}ms内处理完")

    def analyze_computational_efficiency(self):
        """分析计算效率"""
        print("\n" + "=" * 80)
        print("计算效率分析")
        print("=" * 80)

        seq_len = 2048
        batch_size = 1

        # GPU性能参数 (A100 40GB)
        gpu_flops = 312e12  # 312 TFLOPs (FP16)
        gpu_bandwidth = 1935e9  # 1935 GB/s

        # 总FLOPs
        attn_flops = self.calc.attention_flops(seq_len)['total']
        mlp_flops = self.calc.mlp_flops(seq_len)['total']
        norm_flops = 2 * self.calc.layernorm_flops(seq_len)
        total_flops = (attn_flops + mlp_flops + norm_flops) * self.calc.num_layers

        # 总内存访问
        access = self.calc.memory_access(seq_len)['total'] * self.calc.num_layers

        print(f"\n【A100 GPU性能参数】")
        print(f"  FP16 FLOPs: {gpu_flops/1e12:.1f} TFLOPs")
        print(f"  内存带宽: {gpu_bandwidth/1e9:.1f} GB/s")

        print(f"\n【理论性能】")
        print(f"  计算受限时: {total_flops/gpu_flops*1000:>8.2f} ms")
        print(f"  内存受限时: {access/gpu_bandwidth*1000:>8.2f} ms")

        # 实际考虑
        actual_time = max(total_flops/gpu_flops, access/gpu_bandwidth) * 1000
        efficiency = min(gpu_flops, gpu_bandwidth * (total_flops/access)) / gpu_flops * 100

        print(f"\n【估算实际性能】")
        print(f"  单次前向传播: {actual_time:.2f} ms")
        print(f"  硬件利用率: {efficiency:.1f}%")
        print(f"  吞吐量: {1000/actual_time:.1f} tokens/s")

        # Flash Attention影响
        print(f"\n【Flash Attention优化影响】")
        print(f"  标准注意力: 访存 ~ seq_len^2")
        print(f"  Flash Attention: 访存 ~ seq_len (分块计算)")
        print(f"  预计加速: 2-4x (取决于序列长度)")

    def print_summary_table(self):
        """打印总结表"""
        print("\n" + "=" * 80)
        print("资源消耗总结表")
        print("=" * 80)

        seq_lengths = [128, 512, 1024, 2048, 4096]

        print(f"\n【完整资源消耗对比 (batch_size=1, FP16)】")
        print(f"{'序列长度':<10} {'FLOPs':<18} {'内存(MB)':<15} {'带宽(GB/s)':<18} {'算术强度':<15}")
        print("-" * 80)

        for seq_len in seq_lengths:
            # FLOPs
            attn_flops = self.calc.attention_flops(seq_len)['total']
            mlp_flops = self.calc.mlp_flops(seq_len)['total']
            norm_flops = 2 * self.calc.layernorm_flops(seq_len)
            total_flops = (attn_flops + mlp_flops + norm_flops) * self.calc.num_layers

            # 内存
            mem = self.calc.layer_memory(seq_len)['total_per_layer'] * self.calc.num_layers

            # 带宽 (假设10ms延迟)
            access = self.calc.memory_access(seq_len)['total'] * self.calc.num_layers
            bandwidth = access / 1024**3 / 0.01

            # 算术强度
            ai = total_flops / (access / self.calc.dtype_size)

            print(f"{seq_len:<10} {total_flops:>16,} {mem/1024**2:>13.1f} {bandwidth:>16.2f} {ai:>13.2f}")

    def run_analysis(self):
        """运行完整分析"""
        self.load_config()
        self.print_analysis_basis()

        seq_lengths = [128, 256, 512, 1024, 2048, 4096, 8192]

        self.analyze_flops(seq_lengths)
        self.analyze_memory(seq_lengths)
        self.analyze_bandwidth(seq_lengths)
        self.analyze_computational_efficiency()
        self.print_summary_table()

        print("\n" + "=" * 80)
        print("✓ 资源消耗分析完成！")
        print("=" * 80)

    def export_report(self, output_file: str = "resource_analysis_report.txt"):
        """导出分析报告"""
        print(f"\n正在导出报告到 {output_file}...")

        with open(output_file, "w", encoding="utf-8") as f:
            f.write("=" * 80 + "\n")
            f.write("Qwen2.5-1.5B 资源消耗分析报告\n")
            f.write("=" * 80 + "\n\n")

            f.write("【分析依据】\n\n")
            f.write("1. FLOPs计算:\n")
            f.write("   - 矩阵乘法: 2*M*N*K (M个元素，每个需要K次乘法和加法)\n")
            f.write("   - 注意力: ~4*seq_len^2*hidden_size\n")
            f.write("   - MLP: 3*hidden_size*intermediate_size*seq_len\n\n")

            f.write("2. 内存计算:\n")
            f.write("   - FP16: 2 bytes per element\n")
            f.write("   - 注意力分数: seq_len^2 (使用因果掩码减半)\n\n")

            f.write("3. 带宽计算:\n")
            f.write("   - Roofline模型: 算术强度 = FLOPs / 字节访问\n")
            f.write("   - AI < 100: 内存受限 (RTX 3090)\n")
            f.write("   - AI < 300: 内存受限 (A100)\n\n")

            f.write("【资源消耗对比】\n\n")
            f.write("序列长度 | FLOPs(每层) | 内存(MB,每层) | 算术强度 | 受限类型\n")
            f.write("-" * 70 + "\n")

            for seq_len in [512, 1024, 2048, 4096]:
                attn_flops = self.calc.attention_flops(seq_len)['total']
                mlp_flops = self.calc.mlp_flops(seq_len)['total']
                norm_flops = 2 * self.calc.layernorm_flops(seq_len)
                total_flops = attn_flops + mlp_flops + norm_flops

                mem = self.calc.layer_memory(seq_len)['total_per_layer']
                access = self.calc.memory_access(seq_len)['total']
                ai = total_flops / access

                limited = "内存受限" if ai < 100 else ("混合" if ai < 300 else "计算受限")

                f.write(f"{seq_len:^9} | {total_flops:>13,} | {mem/1024**2:>13.1f} | {ai:>9.2f} | {limited}\n")

            f.write("\n【优化建议】\n\n")
            f.write("1. 内存优化:\n")
            f.write("   - 使用Flash Attention: 减少注意力分数矩阵内存\n")
            f.write("   - 梯度检查点: 以计算换内存\n")
            f.write("   - 激活重计算: 推理时丢弃中间激活\n\n")

            f.write("2. 计算优化:\n")
            f.write("   - KV Cache: 避免重复计算历史token\n")
            f.write("   - 量化: FP16→INT8/INT4\n")
            f.write("   - 算子融合: 减少内存访问\n\n")

            f.write("3. 带宽优化:\n")
            f.write("   - 增加batch size: 提高算术强度\n")
            f.write("   - 使用更快的显存: GDDR6 → HBM2e\n")

        print(f"✓ 报告已导出到 {output_file}")


def main():
    """主函数"""
    analyzer = ResourceAnalyzer(MODEL_PATH)
    analyzer.run_analysis()
    analyzer.export_report()


if __name__ == "__main__":
    main()
