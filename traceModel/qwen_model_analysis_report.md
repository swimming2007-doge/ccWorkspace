# Qwen2.5-1.5B 模型结构分析报告

---

## 1. 模型概览

- **模型名称**: Qwen2.5-1.5B-Instruct
- **模型类型**: qwen2
- **架构**: Transformer Decoder

## 2. 配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| 词表大小 | 151936 | 模型可识别的token数量 |
| 隐藏层维度 | 1536 | 模型的内部表示维度 |
| Transformer层数 | 28 | 堆叠的解码器层数 |
| 注意力头数 | 12 | 多头注意力的头数 |
| 中间层维度 | 8960 | MLP层的扩展维度 |
| 最大序列长度 | 32768 | 模型支持的最大输入长度 |

## 3. 模型层级结构

### 3.1 输入层

```
├─ embed_tokens: 词嵌入
│   ├─ 输入: token_ids [batch, seq_len]
│   ├─ 输出: embeddings [batch, seq_len, hidden_size]
│   └─ 作用: 将离散token转换为连续向量
│
└─ rotary_emb: 旋转位置编码
    ├─ 输入: Q, K 向量
    ├─ 输出: 添加位置信息的Q, K
    └─ 作用: 注入相对位置信息
```

### 3.2 Transformer层

每层包含以下组件：

```
├─ input_layernorm: RMSNorm
│   └─ 作用: Pre-norm，稳定注意力输入
│
├─ self_attn: 自注意力
│   ├─ q_proj: 查询投影
│   ├─ k_proj: 键投影
│   ├─ v_proj: 值投影
│   ├─ o_proj: 输出投影
│   └─ 公式: softmax(QK^T/√d)V
│
├─ post_attention_layernorm: RMSNorm
│   └─ 作用: 稳定MLP输入
│
└─ mlp: 前馈网络
    ├─ gate_proj: 门控投影
    ├─ up_proj: 上投影
    ├─ down_proj: 下投影
    └─ 激活: SiLU (SwGLU)
```

## 4. 模块功能详解

### Qwen2Model

- **中文名**: Qwen2核心模型
- **描述**: Qwen2的核心Transformer模型，包含嵌入层、解码器层和输出归一化层

### Qwen2ForCausalLM

- **中文名**: Qwen2因果语言模型
- **描述**: 在Qwen2Model基础上添加语言模型头的完整模型，用于下一个token预测

### model.embed_tokens

- **中文名**: 词嵌入层
- **描述**: 可学习的词嵌入矩阵，将离散的token ID转换为连续的向量表示
- **公式**: `embedding = W[token_id]`
- **作用**: 学习每个token的语义表示

### model.rotary_emb

- **中文名**: 旋转位置编码 (RoPE)
- **描述**: 通过旋转向量方式为注意力机制注入位置信息，不增加额外参数
- **公式**: `q' = q * cos(mθ) + rotate_90(q) * sin(mθ)`
- **作用**: 让模型理解token在序列中的相对位置

### model.layers.*.self_attn

- **中文名**: 自注意力层
- **描述**: 多头自注意力机制，计算序列中每个位置与其他所有位置的相关性
- **公式**: `Attention(Q,K,V) = softmax(QK^T / √d_k) V`

### model.layers.*.self_attn.q_proj

- **中文名**: 查询投影层
- **描述**: 将输入隐藏状态投影为查询向量，用于搜索相关信息
- **公式**: `Q = X @ W_Q`
- **作用**: 生成查询表示，每个位置的查询向量会在整个序列中寻找匹配的键

### model.layers.*.self_attn.k_proj

- **中文名**: 键投影层
- **描述**: 将输入隐藏状态投影为键向量，用于与查询匹配
- **公式**: `K = X @ W_K`
- **作用**: 生成键表示，作为信息的索引

### model.layers.*.self_attn.v_proj

- **中文名**: 值投影层
- **描述**: 将输入隐藏状态投影为值向量，存储实际信息内容
- **公式**: `V = X @ W_V`
- **作用**: 生成值表示，包含需要被聚合的实际信息

### model.layers.*.self_attn.o_proj

- **中文名**: 输出投影层
- **描述**: 将多头注意力的输出融合，投影回原始隐藏维度
- **公式**: `O = Attention_output @ W_O`
- **作用**: 融合多头注意力的结果，恢复到隐藏维度

### model.layers.*.mlp

- **中文名**: 前馈网络层 (MLP)
- **描述**: 使用SwiGLU激活函数的门控前馈网络，在注意力层之后处理信息
- **公式**: `FFN(x) = (SiLU(x @ W_gate) ⊙ (x @ W_up)) @ W_down`

### model.layers.*.mlp.gate_proj

- **中文名**: 门控投影层
- **描述**: SwiGLU架构中的门控分支，控制信息的流动
- **公式**: `gate = SiLU(X @ W_gate)`
- **作用**: 生成0-1之间的门控值，动态调节上投影的输出

### model.layers.*.mlp.up_proj

- **中文名**: 上投影层
- **描述**: SwiGLU架构中的上投影分支，扩展隐藏维度
- **公式**: `up = X @ W_up`
- **作用**: 将特征投影到更高维空间，增加表达能力

### model.layers.*.mlp.down_proj

- **中文名**: 下投影层
- **描述**: SwiGLU架构中的下投影分支，融合门控和上投影结果并降维
- **公式**: `down = (gate ⊙ up) @ W_down`
- **作用**: 融合两个分支的特征，并投影回原始维度

### model.layers.*.input_layernorm

- **中文名**: 输入层归一化
- **描述**: 在自注意力层之前对输入进行归一化
- **公式**: `x̂ = x * γ / sqrt(mean(x²) + ε)`
- **作用**: 稳定注意力层的输入分布，防止数值不稳定

### model.layers.*.post_attention_layernorm

- **中文名**: 后注意力层归一化
- **描述**: 在MLP层之前对注意力输出进行归一化
- **公式**: `x̂ = x * γ / sqrt(mean(x²) + ε)`
- **作用**: 稳定MLP层的输入分布

### model.norm

- **中文名**: 最终归一化层
- **描述**: 在所有Transformer层之后，输出之前的最终归一化
- **作用**: 规范化最终输出，为语言模型头准备输入

### lm_head

- **中文名**: 语言模型头
- **描述**: 将隐藏状态投影到词表空间，用于预测下一个token
- **公式**: `logits = X @ W_lm_head`
- **作用**: 预测每个位置下一个token的概率分布

### DynamicCache

- **中文名**: 动态缓存
- **描述**: 用于推理过程中缓存已计算token的键值对

### CausalLMOutputWithPast

- **中文名**: 因果语言模型输出
- **描述**: 包含损失、logits、隐藏状态和过去键值对的输出格式

