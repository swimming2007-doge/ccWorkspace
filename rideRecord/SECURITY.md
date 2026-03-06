# 安全策略

感谢您关注 RideRecord 的安全！我们非常重视安全问题，并将尽最大努力确保项目的安全性。

---

## 支持的版本

| 版本 | 支持状态 |
| ---- | -------- |
| 0.1.x | ✅ 支持 |
| < 0.1 | ❌ 不支持 |

---

## 报告安全漏洞

如果您发现安全漏洞，请**不要**通过公开的 GitHub Issue 报告。请按照以下步骤安全地报告：

### 报告方式

1. **发送邮件**: 将漏洞详情发送至 `security@riderecord.example.com`

2. **邮件内容**:
   - 漏洞类型（如：XSS、SQL注入、认证绕过等）
   - 受影响的功能/端点
   - 复现步骤
   - 概念验证代码（如适用）
   - 影响范围
   - 可能的修复建议（如有）

### 响应时间

- **确认收到**: 48 小时内
- **初步评估**: 7 天内
- **修复计划**: 根据严重程度，通常 14-30 天

---

## 安全最佳实践

### 用户端

1. **账号安全**
   - 使用强密码
   - 定期更换密码
   - 不要分享账号

2. **数据安全**
   - 定期备份骑行数据
   - 不要在公共网络进行敏感操作
   - 及时更新应用版本

3. **隐私保护**
   - 检查分享设置
   - 注意位置信息分享
   - 定期清理敏感数据

### 开发者端

1. **代码安全**
   ```typescript
   // ✅ 正确：参数化查询
   const user = await db.query('SELECT * FROM users WHERE id = ?', [userId]);

   // ❌ 错误：字符串拼接
   const user = await db.query(`SELECT * FROM users WHERE id = ${userId}`);
   ```

2. **输入验证**
   ```typescript
   // 验证用户输入
   function sanitizeInput(input: string): string {
     return input
       .replace(/</g, '&lt;')
       .replace(/>/g, '&gt;')
       .replace(/"/g, '&quot;')
       .replace(/'/g, '&#x27;');
   }
   ```

3. **认证和授权**
   - 使用 HTTPS
   - 实现 Token 过期机制
   - 验证用户权限

4. **敏感数据处理**
   - 不要在日志中记录敏感信息
   - 加密存储敏感数据
   - 使用环境变量管理密钥

---

## 已知安全问题

### 已修复

| CVE | 描述 | 影响版本 | 修复版本 |
|-----|------|----------|----------|
| - | 目前无已知漏洞 | - | - |

---

## 安全更新

安全更新将通过以下方式发布：

1. GitHub Security Advisories
2. 应用内更新通知
3. 官方网站公告

---

## 安全相关配置

### 环境变量

```bash
# .env.example
# 复制为 .env 并填入真实值

# 服务端密钥
JWT_SECRET=your-jwt-secret-key
ENCRYPTION_KEY=your-encryption-key

# 数据库
DATABASE_URL=your-database-url

# 第三方服务
STRAVA_CLIENT_ID=your-strava-client-id
STRAVA_CLIENT_SECRET=your-strava-client-secret
WECHAT_APP_ID=your-wechat-app-id
WECHAT_APP_SECRET=your-wechat-app-secret

# 云存储
OBS_ACCESS_KEY=your-obs-access-key
OBS_SECRET_KEY=your-obs-secret-key
```

### HTTPS 配置

```typescript
// 生产环境强制 HTTPS
app.use((req, res, next) => {
  if (req.header('x-forwarded-proto') !== 'https' && process.env.NODE_ENV === 'production') {
    res.redirect(`https://${req.header('host')}${req.url}`);
  } else {
    next();
  }
});
```

### 安全头配置

```typescript
// 使用 Helmet 添加安全头
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", 'https://api.strava.com'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
}));
```

---

## 漏洞奖励计划

目前我们没有正式的漏洞奖励计划，但我们会在安全公告中感谢负责任披露漏洞的研究人员。

### 认可方式

- 在安全公告中提及（经同意）
- 在贡献者列表中添加
- 项目 README 中的特别感谢

---

## 安全联系信息

- **安全邮箱**: security@riderecord.example.com
- **PGP 公钥**: [待添加]
- **响应时间**: 工作日 9:00-18:00 (UTC+8)

---

## 安全政策更新

本安全政策可能会定期更新。重大变更将在 GitHub 仓库公告。

---

感谢您帮助保护 RideRecord 及其用户的安全！🔒
