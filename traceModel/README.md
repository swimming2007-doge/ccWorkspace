# Qwen 模型结构分析工具

这是一个用于分析 Qwen2.5-1.5B 模型结构的工具包，提供详细的模块功能介绍和架构解析。

## 文件说明

### 主要脚本

| 文件名 | 说明 | 特点 |
|--------|------|------|
| `quick_model_analyzer.py` | 快速分析脚本（推荐） | 只读取配置文件，快速生成详细报告 |
| `advanced_model_analyzer.py` | 高级分析脚本 | 加载完整模型，包含TorchVista追踪 |
| `analyze_qwen_model.py` | 基础分析脚本 | 基础的结构分析功能 |

### 配置和输出

| 文件名 | 说明 |
|--------|------|
| `requirements.txt` | Python依赖包列表 |
| `qwen_model_analysis_report.md` | 自动生成的Markdown格式分析报告 |
| `output_full.txt` | 控制台完整输出 |

## 快速开始

### 1. 安装依赖

```bash
pip install torch transformers accelerate safetensors
```

或使用提供的 requirements.txt：

```bash
pip install -r requirements.txt
```

### 2. 运行快速分析（推荐）

```bash
python quick_model_analyzer.py
```

此脚本会：
- 读取模型配置文件
- 分析模型结构
- 生成详细的功能说明
- 导出 Markdown 报告

### 3. 运行高级分析（需要加载完整模型）

```bash
python advanced_model_analyzer.py
```

此脚本会：
- 加载完整的 Qwen 模型（约3GB）
- 使用 TorchVista 追踪前向传播
- 分析每层的参数和功能
- 生成更详细的分析报告

## 模型信息

```
模型名称: Qwen2.5-1.5B-Instruct
架构: Transformer Decoder
总参数量: ~1.89B

核心配置:
- 词表大小: 151,936
- 隐藏层维度: 1,536
- Transformer层数: 28
- 注意力头数: 12
- 中间层维度: 8,960
- 最大序列长度: 32,768
```

## 模型结构概览

```
输入层
  ├─ embed_tokens: 词嵌入 (151936 × 1536)
  └─ rotary_emb: 旋转位置编码 (RoPE)

Transformer解码器层 (×28)
  ├─ input_layernorm: RMSNorm
  ├─ self_attn: 自注意力 (12头)
  │   ├─ q_proj: 查询投影
  │   ├─ k_proj: 键投影
  │   ├─ v_proj: 值投影
  │   └─ o_proj: 输出投影
  ├─ post_attention_layernorm: RMSNorm
  └─ mlp: 前馈网络 (SwiGLU)
      ├─ gate_proj: 门控投影
      ├─ up_proj: 上投影
      └─ down_proj: 下投影

输出层
  ├─ norm: 最终归一化
  └─ lm_head: 语言模型头
```

## 核心技术

### 1. 多头自注意力 (MHA)
- 捕捉序列中的长距离依赖
- 12个注意力头，每头128维
- 公式: `Attention(Q,K,V) = softmax(QK^T/√d)V`

### 2. SwiGLU 前馈网络
- 门控线性单元的改进版本
- 使用 SiLU 激活函数
- 公式: `FFN(x) = (SiLU(x @ W_gate) ⊙ (x @ W_up)) @ W_down`
- 优势: 更好的梯度流动和参数效率

### 3. RMSNorm 归一化
- 均方根层归一化
- 公式: `RMSNorm(x) = x * γ / √(mean(x²) + ε)`
- 优势: 计算效率高，训练稳定

### 4. RoPE 旋转位置编码
- 旋转位置编码
- 优势: 支持任意长度，可外推
- 无需额外参数

### 5. Pre-norm 架构
- 归一化在子层之前
- 优势: 深层网络训练更稳定

## 模块功能详解

脚本提供了每个模块的详细功能说明，包括：

- **中文名称**: 便于理解
- **描述**: 模块的功能和作用
- **输入输出形状**: 数据流转
- **公式**: 数学公式表示
- **关键点**: 重要特性
- **优势**: 相比其他方法的优势

## 输出说明

运行脚本后会生成：

1. **控制台输出**: 实时显示分析进度和结果
2. **Markdown报告**: `qwen_model_analysis_report.md` - 格式化的分析报告
3. **完整文本**: `output_full.txt` - 包含所有输出的文本文件

## 自定义分析

### 修改模型路径

在脚本中修改 `MODEL_PATH` 变量：

```python
MODEL_PATH = r"你的模型路径"
```

### 分析其他 Qwen 模型

脚本支持分析 Qwen 系列的所有模型，只需修改模型路径即可。

## 注意事项

1. **快速分析**: `quick_model_analyzer.py` 只需几秒钟，推荐使用
2. **高级分析**: `advanced_model_analyzer.py` 需要加载完整模型，耗时较长
3. **内存要求**: 高级分析需要约 4-6GB 内存
4. **编码问题**: 脚本已修复 Windows 编码问题，可直接运行

## 依赖包

```
torch>=2.0.0
transformers>=4.37.0
accelerate>=0.25.0
safetensors
```

## 许可证

本分析工具仅供学习和研究使用。

## 参考资料

- Qwen 官方文档: https://github.com/QwenLM/Qwen
- Transformers 文档: https://huggingface.co/docs/transformers
