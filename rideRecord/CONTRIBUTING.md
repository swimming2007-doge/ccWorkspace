# 贡献指南

感谢您有兴趣为 RideRecord 做出贡献！

---

## 目录

- [行为准则](#行为准则)
- [如何贡献](#如何贡献)
- [开发环境设置](#开发环境设置)
- [代码规范](#代码规范)
- [提交信息规范](#提交信息规范)
- [Pull Request 流程](#pull-request-流程)
- [问题报告](#问题报告)

---

## 行为准则

### 我们的承诺

为了营造一个开放和友好的环境，我们作为贡献者和维护者承诺：无论年龄、体型、残疾、种族、性别认同和表达、经验水平、教育程度、社会经济地位、国籍、外貌、种族、宗教或性取向如何，参与我们的项目和社区都将为每个人提供无骚扰的体验。

### 我们的标准

积极行为的例子包括：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

---

## 如何贡献

### 报告 Bug

如果您发现了 bug，请创建一个 [Issue](https://github.com/your-org/riderecord/issues) 并包含：

1. **Bug 描述**: 清楚简洁地描述 bug
2. **复现步骤**: 详细说明如何复现
3. **预期行为**: 描述您期望发生什么
4. **实际行为**: 描述实际发生了什么
5. **截图**: 如果适用，添加截图
6. **环境信息**:
   - 设备型号
   - 系统版本
   - 应用版本

### 建议新功能

如果您有新功能建议，请创建一个 [Issue](https://github.com/your-org/riderecord/issues) 并包含：

1. **功能描述**: 详细描述功能
2. **使用场景**: 说明这个功能解决什么问题
3. **期望实现**: 如果有想法，描述期望的实现方式

### 提交代码

1. Fork 本仓库
2. 创建您的功能分支 (`git checkout -b feature/amazing-feature`)
3. 进行更改并确保通过测试
4. 提交您的更改 (`git commit -m 'feat: add amazing feature'`)
5. 推送到分支 (`git push origin feature/amazing-feature`)
6. 创建 Pull Request

---

## 开发环境设置

### 前置要求

- Node.js 20 LTS
- DevEco Studio 5.0+
- HarmonyOS NEXT SDK
- Git

### 设置步骤

```bash
# 1. Fork 并克隆仓库
git clone https://github.com/YOUR_USERNAME/riderecord.git
cd riderecord

# 2. 安装服务端依赖
cd server
npm install

# 3. 安装 Web 端依赖
cd ../web
npm install

# 4. 设置环境变量
cp .env.example .env
# 编辑 .env 文件填入配置

# 5. 启动开发服务器
npm run dev
```

### 项目结构

```
rideRecord/
├── phone/          # 手机端 (HarmonyOS)
├── watch/          # 手表端 (Watch OS)
├── server/         # 服务端 (Node.js)
├── web/            # Web 端 (Vue 3)
├── shared/         # 共享代码
└── docs/           # 文档
```

---

## 代码规范

### TypeScript/ArkTS

```typescript
// 使用接口定义类型
interface UserInfo {
  id: string;
  name: string;
  email: string;
}

// 使用箭头函数
const formatDate = (timestamp: number): string => {
  return new Date(timestamp).toLocaleDateString();
};

// 使用 async/await
async function fetchData(): Promise<UserInfo[]> {
  try {
    const response = await api.get('/users');
    return response.data;
  } catch (error) {
    console.error('Failed to fetch users:', error);
    return [];
  }
}
```

### 组件规范 (ArkUI)

```typescript
@Component
export struct MyComponent {
  // 1. 属性定义
  @Prop title: string = '';
  @State count: number = 0;

  // 2. 私有方法
  private handleClick(): void {
    this.count++;
  }

  // 3. 构建方法
  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.MEDIUM)

      Button(`Count: ${this.count}`)
        .onClick(() => this.handleClick())
    }
    .padding(16)
  }
}
```

### 文件命名

- 组件: `PascalCase.ets` (例如 `UserProfile.ets`)
- 服务: `PascalCase` + `Service.ets` (例如 `AuthService.ets`)
- 页面: `PascalCase` + `Page.ets` (例如 `LoginPage.ets`)
- 工具: `camelCase.ts` (例如 `dateUtils.ts`)

### 注释规范

```typescript
/**
 * 用户服务
 *
 * 功能说明：
 * - 用户注册和登录
 * - Token 管理
 * - 权限验证
 *
 * SRS引用: FR-009
 */
export class UserService {
  /**
   * 用户登录
   * @param username 用户名
   * @param password 密码
   * @returns 登录结果
   */
  async login(username: string, password: string): Promise<LoginResult> {
    // 实现逻辑
  }
}
```

---

## 提交信息规范

我们使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

### 格式

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### 类型 (type)

| 类型 | 描述 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响代码运行的变动） |
| `refactor` | 重构（既不是新增功能，也不是修改 bug） |
| `perf` | 性能优化 |
| `test` | 增加测试 |
| `chore` | 构建过程或辅助工具的变动 |
| `revert` | 回退 |

### 示例

```bash
# 新功能
feat(phone): 添加心率区间显示功能

# Bug 修复
fix(watch): 修复动作检测延迟问题

# 文档
docs: 更新 README 安装说明

# 重构
refactor(server): 重构认证服务代码结构
```

---

## Pull Request 流程

### PR 检查清单

- [ ] 代码符合项目的代码规范
- [ ] 已进行自我代码审查
- [ ] 代码已添加适当的注释
- [ ] 文档已更新（如需要）
- [ ] 没有引入新的警告
- [ ] 添加了必要的测试
- [ ] 所有测试都通过

### PR 标题格式

使用与提交信息相同的格式：

```
feat(phone): 添加新的分享模板
```

### PR 描述模板

```markdown
## 变更类型
- [ ] Bug 修复
- [ ] 新功能
- [ ] 重构
- [ ] 文档更新
- [ ] 其他

## 变更说明
<!-- 描述这个 PR 解决的问题或添加的功能 -->

## 测试说明
<!-- 描述如何测试这些变更 -->

## 截图（如适用）
<!-- 添加截图说明变更 -->

## 相关 Issue
<!-- 关联的 Issue，例如: Fixes #123 -->
```

### 审核流程

1. 提交 PR 后，维护者会进行代码审核
2. 根据审核意见进行必要的修改
3. 通过所有检查后，维护者会合并 PR

---

## 问题报告

### 安全问题

如果您发现安全漏洞，请**不要**通过公开 Issue 报告。请查看 [SECURITY.md](SECURITY.md) 了解如何安全地报告安全问题。

### 一般问题

对于一般问题和讨论，请：

1. 先搜索现有的 [Issues](https://github.com/your-org/riderecord/issues)
2. 如果没有相关问题，创建新 Issue
3. 使用清晰的标题和详细的描述

---

## 联系方式

- GitHub Issues: https://github.com/your-org/riderecord/issues
- 邮件: riderecord@example.com

---

再次感谢您的贡献！🎉
