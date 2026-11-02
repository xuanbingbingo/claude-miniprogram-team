---
name: miniprogram-team
description: 微信小程序开发团队总指挥剧本（11 Phase 契约驱动 + 任务级 Dev-QA Loop）。当用户需要开发包含后端的微信小程序应用、说"用小程序团队开发"、"小程序团队"时激活。主会话作为调度者，按本剧本通过 Task 工具直接派遣成员 agent，不存在中间 orchestrator agent。
---

# 微信小程序开发团队总指挥剧本

> **执行模型**：本 skill 是**主会话执行的剧本**，不是一个独立运行的 agent。
> 主会话读完本剧本后，用 `Task` 工具**直接**派遣成员 agent（按下方 Phase 0-11 顺序），可并行的并行。
>
> **为什么是 skill 不是 agent**：Claude Code 平台限制 —— subagent 不能 spawn 其他 subagent，Task 工具会被运行时强制剥离。所以"总指挥"必须由主会话亲自担任，剧本以 skill 形式装载。详见 `reference_subagent_nesting_proof.md`（5-8 沙箱实测铁证）。

---

# 启动时必须确认的参数

调用此 skill 时，用户需提供（未提供则主动询问）：

```
小程序框架：uni-app / 原生小程序 / Taro（不确定可先选 uni-app）
APP_PATH：后端部署路径前缀（如 myapp），决定 BASE_URL 中的路径部分
DOMAIN：后端服务域名（如 api.example.com），必须支持 HTTPS
是否需要微信登录：是 / 否（影响 API 契约和后端实现）
```

---

# 角色定义

你（主会话）是总指挥，整合两种质量保障机制：
- **契约层**（事前）：强迫所有 agent 在动手前对齐接口和数据结构
- **Dev-QA Loop**（事中）：每个任务实现后立即由 EvidenceCollector 验证

你不写任何业务代码。你的职责是调度、传递契约、决策打回。
所有过程产出的 md 文件，都使用中文来描述。

---

# 团队成员

## 规划层
| Agent | 职责 |
|-------|------|
| `product-manager` | PRD、用户故事、MVP 范围 |
| `software-architect` | 技术选型、API 契约、DB Schema |

## 实现层
| Agent | 职责 |
|-------|------|
| `miniprogram-ui-designer` | 小程序设计规范、variables.wxss |
| `database-optimizer` | Schema 实现、迁移文件、start.sh |
| `backend-architect` | API 实现（含微信登录接口） |
| `miniprogram-developer` | 小程序页面和组件 |
| `devops-automator` | 后端 Dockerfile + docker-compose（无前端容器） |

## 质量层
| Agent | 职责 |
|-------|------|
| `testing-evidence-collector` | 代码层面 QA（无法截图真机，验证逻辑和字段） |
| `security-engineer` | 安全扫描 |
| `code-reviewer` | 代码规范 review |
| `reality-checker` | 最终验收 |

## 文档层
| Agent | 职责 |
|-------|------|
| `technical-writer` | README + API 文档 + 上线操作指南 |

---

# 🔴 派遣铁律：成员 agent 一律前台派（2026-11-03 血教训）

- 每次 `Agent` / `Task` 派成员，**必须显式 `run_in_background: false`**，同步等结果回来再进下一步；Bash 同样禁用 `run_in_background`。
  - 理由：剧本是串行契约链（PRD → 契约 → 实现 → QA），下一步本来就依赖上一步产出，后台派没有任何并行收益；
  - 而在 `claude -p` 无人值守运行时，后台 agent 未结束主进程最多等 600 秒就自杀——2026-11-03 小程序团队（membercard-mp）就这样在 Phase 2 被腰斩，架构师写了一半 TECH_SPEC，契约全空。
- 真正可并行的（同一 Phase 内互不依赖的成员），在**同一条消息里发多个前台 Agent 调用**，不要用后台。
- 要无人值守整条跑完：用 `detach-run --name <标签> -- claude -p --dangerously-skip-permissions "<任务书>"` 提交（detach-run 已自动注入 `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0` 兜底）；任务书里要求每个 Phase 往 `plans/PROGRESS.md` 追加一行，作为唯一进度窗口。

---

# 完整执行流程

---

## ► Audit 模式（已有代码审查）

> **触发方式**：用户说"审查 xxx 项目"、"audit xxx"、"检查现有代码"时进入此模式，不走 Phase 0–11。

### Audit-1：代码审查

**调用 `code-reviewer`**

```
输入：项目源码目录（用户指定，或默认当前工作目录）
重点检查（除常规项外，必须额外扫描）：
  - WECHAT_APPID / WECHAT_SECRET 是否从环境变量读取（禁止硬编码）
  - 请求是否通过 utils/request.js 发出（无直接 wx.request）
  - URL 是否只写 /api/v1/... 路径（无硬编码域名）
  - 样式是否使用变量（无硬编码色值/字号/间距）

产出：docs/REVIEW_REPORT.md
```

### Audit-2：安全扫描

**调用 `security-engineer`**

```
输入：项目源码目录
产出：docs/SECURITY_REPORT.md
```

### Audit 汇报格式

```
🔍 Audit 完成：{项目名}

🔴 必须修复（Blocker）：[n] 项
  - [具体问题 + 文件:行号]

🟡 建议修复：[n] 项
🔒 安全问题：[高危 n / 中危 n / 低危 n]
✅ 未发现问题的检查项：[列出]
```

**有 Blocker → 打回对应 agent 修复 → 重新 audit**
**无 Blocker → 汇报完成，等待用户指令**

---

## ► Phase 0：初始化目录

```bash
mkdir -p docs project-tasks miniprogram/styles miniprogram/utils miniprogram/config backend
```

创建以下文件占位：
```
docs/
  PRD.md
  TECH_SPEC.md
  API_CONTRACT.md
  DB_SCHEMA.md
  DESIGN_SYSTEM.md
  BACKEND_STATUS.md
  SECURITY_REPORT.md
  REVIEW_REPORT.md
  QA_REPORT.md
  ACCEPTANCE_REPORT.md
project-tasks/
  backend-tasklist.md
  miniprogram-tasklist.md
```

---

## ► Phase 1：需求分析

**调用 `product-manager`**

```
输入：用户原始需求
产出：docs/PRD.md

要求：
- 功能编号 F01/F02...
- 明确区分：哪些功能在小程序端，哪些在管理后台（如有）
- 用户故事 Who/What/Why 格式
- 明确 MVP 范围（✅本期 / ❌不做）
- 标注是否需要微信登录（影响后续契约设计）
```

**⏸ 人工检查点**：展示 PRD 功能列表，等待用户确认后继续。

---

## ► Phase 2：技术架构 + 契约生成

**调用 `software-architect`**

```
输入：docs/PRD.md + 启动参数（框架、DOMAIN、APP_PATH）
产出：
  - docs/TECH_SPEC.md
  - docs/API_CONTRACT.md
  - docs/DB_SCHEMA.md

TECH_SPEC.md 必须包含：
  - 小程序框架：[uni-app / 原生 / Taro]
  - 后端技术栈：Node.js + Koa2/Express + MySQL
  - BASE_URL 配置规范：
      开发环境：http://localhost:3000
      生产环境：https://{DOMAIN}/{APP_PATH}
  - 小程序 AppID（占位，由用户填入）

API_CONTRACT.md 若需要微信登录，必须包含：
  POST /api/wx/login
    Request:  { code: string }         // wx.login() 返回的 code
    Response: { token: string, user: { id, openid, nickname, avatarUrl } }
    说明：后端用 code 换取 openid，签发 JWT

所有接口必须完整定义 Request/Response/错误码，不得有模糊表述。
```

**⏸ 人工检查点**：展示 API 接口列表 + 表结构摘要，等待用户确认后继续。

---

## ► Phase 2.5：小程序设计规范

**调用 `miniprogram-ui-designer`**

```
输入：docs/PRD.md、docs/TECH_SPEC.md
产出：
  - docs/DESIGN_SYSTEM.md
  - miniprogram/styles/variables.wxss

要求：
  - 色彩体系与产品定位匹配
  - 所有尺寸使用 rpx
  - 变量定义在 page {} 选择器内（WXSS 规范）
  - 针对 PRD 中的核心组件给出视觉规范
```

---

## ► Phase 3：任务拆解

**由主会话亲自执行**（不调用子 agent）

读取 `docs/API_CONTRACT.md` 和 `docs/DB_SCHEMA.md`，生成：

**project-tasks/backend-tasklist.md**
```markdown
# 后端任务清单
> 基于 API_CONTRACT v1.0，每任务对应一个接口

### [ ] TASK-B01：实现 POST /api/wx/login
- 对应契约：API_CONTRACT.md #wx-login
- 验收标准：返回 { token, user } 结构与契约一致
```

**project-tasks/miniprogram-tasklist.md**
```markdown
# 小程序任务清单
> 框架：[uni-app / 原生 / Taro]

### [ ] TASK-MP01：初始化工程结构
- 创建 config/index.js（BASE_URL 配置）
- 创建 utils/request.js（统一请求封装）
- 创建 utils/auth.js（微信登录封装，如需要）
- 引入 styles/variables.wxss

### [ ] TASK-MP02：登录页面
- 调用：POST /api/wx/login（或用户名密码登录）
- 验收：token 正确存储，登录后跳转首页

### [ ] TASK-MP03：[业务页面...]
- 调用契约：[对应接口]
- 验收标准：[字段和样式要求]
```

---

## ► Phase 4：数据库实现

**调用 `database-optimizer`**

```
输入：docs/DB_SCHEMA.md、docs/TECH_SPEC.md
产出：backend/migrations/、backend/src/migrate.js、backend/start.sh

要求：
- 字段名严格与 DB_SCHEMA 一致，不得自行修改
- 若发现 Schema 有问题，写入 docs/DB_ISSUES.md 并停止
- 必须创建迁移运行基础设施（migrate.js + start.sh）
- 不需要 Dev-QA Loop（纯结构性任务）
```

若 `docs/DB_ISSUES.md` 存在 → 打回 `software-architect` 修正 DB_SCHEMA → 重试。

---

## ► Phase 5：后端实现（含 Dev-QA Loop）

**逐任务执行以下循环：**

```
FOR 每个 project-tasks/backend-tasklist.md 中的 [ ] 任务：

  STEP 1 - 调用 backend-architect 实现该任务：
    输入：
      - docs/API_CONTRACT.md（必须第一步）
      - docs/DB_SCHEMA.md
      - 当前任务描述
    特别要求（微信登录接口）：
      - 调用微信 API：https://api.weixin.qq.com/sns/jscode2session
        参数：appid、secret、js_code、grant_type=authorization_code
      - 获取 openid 后签发 JWT
      - AppID 和 AppSecret 从环境变量读取（WECHAT_APPID、WECHAT_SECRET）
      - 必须实现 GET /api/health 健康检查端点
      - server.js 必须实现 waitForDB() 重试机制

  STEP 2 - 调用 testing-evidence-collector 验证：
    验证：路径、字段名与契约一致，错误处理覆盖完整
    产出：PASS 或 FAIL + 具体原因
    追加写入：docs/QA_REPORT.md

  STEP 3 - 决策：
    PASS → 标记 [x]，进入下一任务
    FAIL（重试 < 3）→ 将 QA 反馈传给 backend-architect，重新实现
    FAIL（重试 >= 3）→ 暂停，向用户报告卡点，等待介入
```

---

## ► Phase 6：小程序实现（含 Dev-QA Loop）

**逐任务执行以下循环：**

```
FOR 每个 project-tasks/miniprogram-tasklist.md 中的 [ ] 任务：

  STEP 1 - 调用 miniprogram-developer 实现该任务：
    输入：
      - docs/API_CONTRACT.md（接口定义）
      - docs/DESIGN_SYSTEM.md（样式规范）
      - docs/TECH_SPEC.md（框架类型、BASE_URL 规范）
      - 当前任务描述
    框架参数：[uni-app / 原生 / Taro]（来自 TECH_SPEC.md）

  STEP 2 - 调用 testing-evidence-collector 验证：
    验证内容：
      - 请求是否通过 utils/request.js 发出（无直接 wx.request）
      - URL 是否只写 /api/v1/... 路径（无硬编码域名）
      - 字段名与契约一致
      - 样式是否使用变量（无硬编码色值/字号/间距）
    产出：PASS 或 FAIL + 具体原因
    追加写入：docs/QA_REPORT.md

  STEP 3 - 决策：
    PASS → 标记 [x]，进入下一任务
    FAIL（重试 < 3）→ 将 QA 反馈传给 miniprogram-developer，重新实现
    FAIL（重试 >= 3）→ 暂停，向用户报告卡点，等待介入
```

---

## ► Phase 7：安全审查

**调用 `security-engineer`**

```
输入：扫描 backend/src/ 目录 + miniprogram/ 目录
产出：docs/SECURITY_REPORT.md

重点检查（小程序额外关注）：
- WECHAT_APPID / WECHAT_SECRET 是否从环境变量读取（禁止硬编码）
- 微信登录接口是否有频率限制（防刷）
- JWT 签名密钥是否足够强度
- 其他标准安全项（SQL 注入、XSS、鉴权缺失等）

【封号高风险项强制检查】：
1. 隐私协议合规：
   - manifest.json / app.json 中 __usePrivacyCheck__ 必须为 true
   - 若使用 chooseMedia / getLocation 等隐私 API，必须配置 privacy.json
   - 必须实现隐私协议弹窗组件（open-type="agreePrivacyAuthorization"）

2. API 接口鉴权：
   - 所有非健康检查接口必须校验微信登录态（X-WX-Code 或 JWT）
   - 禁止出现无鉴权的上传 / 识别 / 支付等敏感接口
   - 后端必须有 code2Session 校验，禁止只校验 code 不校验 openid

3. CORS 跨域策略：
   - 后端 CORS 的 origin 绝对不能是 "*"
   - 生产环境应只允许小程序域名，或留空拒绝跨域

4. 限流策略：
   - 必须基于用户身份（openid / userId）限流，不能仅基于 IP
   - 需有分钟 + 小时双维度限制
   - 返回 429 时前端需友好提示

安全检查不通过 → 必须先修复后才能进入 Phase 8
```

---

## ► Phase 8：代码 Review

**调用 `code-reviewer`**

```
输入：项目全量代码，读取 docs/TECH_SPEC.md（规范参考）
产出：docs/REVIEW_REPORT.md

检查项：代码规范、性能问题、可维护性、错误处理
若有 MUST FIX 级别问题 → 打回对应 agent → 重新 review
```

---

## ► Phase 9：DevOps 配置（后端 + 小程序 CI/CD）

**调用 `devops-automator`**

```
输入：docs/TECH_SPEC.md
产出：
  - backend/Dockerfile（非 root 用户，CMD 使用 start.sh）
  - docker-compose.yml（仅 backend + mysql，无前端容器）
  - .github/workflows/deploy.yml（后端 CI/CD，同标准链路）
  - .github/workflows/miniprogram.yml（小程序上传 CI/CD）
  - scripts/mp-upload.js（miniprogram-ci 上传脚本）

⚠️ 小程序项目特别说明：
  - 不生成前端 Dockerfile
  - 不生成 nginx.conf（小程序无前端容器）
  - docker-compose 只包含 backend + mysql 两个服务
  - 后端环境变量必须包含 WECHAT_APPID 和 WECHAT_SECRET 占位
  - nginx-gateway 只需注册后端 API 路由（无前端路由）：
      location /{APP_PATH}/api/ {
          rewrite ^/{APP_PATH}(/api/.*)$ $1 break;
          proxy_pass http://{APP_NAME}-backend:3000;
      }

输出 GitHub Secrets 配置清单：
  SERVER_HOST        服务器 IP
  SERVER_USER        SSH 用户（root）
  SERVER_SSH_KEY     SSH 私钥内容
  WECHAT_APPID       小程序 AppID
  WECHAT_PRIVATE_KEY 代码上传密钥（微信后台生成的 .key 文件内容）
```

---

## ► Phase 10：最终验收

**调用 `reality-checker`**

```
输入：
  - docs/API_CONTRACT.md
  - project-tasks/ 所有任务清单（验证全部 [x]）
  - docs/SECURITY_REPORT.md
  - docs/REVIEW_REPORT.md
  - docs/QA_REPORT.md

判决规则：
  - 默认判决：NEEDS WORK（必须有压倒性证据才能 READY）
  - READY 条件：
      ✅ 所有任务清单项均为 [x]
      ✅ 无未解决的安全高危问题
      ✅ API_CONTRACT 中所有接口均有测试通过记录

产出：
  - 判决摘要（返回主会话）
  - 写入 docs/ACCEPTANCE_REPORT.md
```

---

## ► Phase 11：文档

**调用 `technical-writer`**

```
产出：README.md 必须包含：
  - 项目说明 + 技术栈（后端 + 小程序框架）
  - 本地开发启动方式（后端 + 小程序开发者工具）
  - 环境变量说明（含 WECHAT_APPID、WECHAT_SECRET）
  - 后端首次部署步骤
  - 小程序上线操作步骤：
      1. 微信后台配置合法域名（https://{DOMAIN}）
      2. 生成代码上传密钥，配置 GitHub Secrets（WECHAT_APPID / WECHAT_PRIVATE_KEY）
      3. 确认 miniprogram/config/index.js 中 production.BASE_URL 正确
      4. GitHub Actions → Upload Miniprogram → Run workflow（自动上传体验版）
      5. 微信后台提交审核 → 审核通过后手动发布
  - 数据库迁移使用说明
```

---

# Subagent 中断与续传机制

> 与标准团队一致。Subagent 报错后：
> 1. 不要立即重派
> 2. `ls` 检查 deliverables 清单中每个路径
> 3. 抽查 1-2 个关键文件确认完整性
> 4. 派同类型新 agent，prompt 包含续传说明（已完成文件不重写，只补缺失项）

| 中断类型 | 最大续传次数 | 超限处理 |
|---------|------------|---------|
| 平台错误（502 / network） | 2 次 | 暂停 → 向用户报告 |
| Context/turns 耗尽 | 1 次续传，第 2 次必须降级 | 暂停 |

---

# 打回重试总规则

| 触发条件 | 打回目标 | 最大重试 |
|---------|---------|---------|
| DB_ISSUES.md 存在 | software-architect | 2次 |
| 后端任务 QA FAIL | backend-architect | 3次/任务 |
| 小程序任务 QA FAIL（硬编码域名） | miniprogram-developer（零容忍） | 3次/任务 |
| 小程序任务 QA FAIL（硬编码样式值） | miniprogram-developer | 3次/任务 |
| 安全高危问题 | 对应 agent | 2次 |
| REVIEW MUST FIX | 对应 agent | 2次 |
| reality-checker NEEDS WORK | 对应 agent | 1次 |
| 任何重试超限 | 暂停 → 向用户报告卡点 | — |

---

# 人工介入检查点

以下节点完成后主动暂停，等待用户"继续"：

1. **Phase 1 后**：展示 PRD 功能列表（F01/F02...）
2. **Phase 2 后**：展示 API 接口列表 + 数据库表结构
3. **任意重试超限时**：展示失败详情，等待用户决策

其余阶段自动执行，不打扰用户。

---

# 人工操作清单（skill 完成后）

skill 输出的是可交付代码，以下步骤需要用户手动完成：

**后端部署（走标准链路）：**
```
1. GitHub 建仓库，推送代码
2. 配置 GitHub Secrets：SERVER_HOST / SERVER_USER / SERVER_SSH_KEY
3. 新服务器运行 infra-bootstrap-agent
4. 调用 app-deploy-agent 首次部署后端
   - 首次部署会在服务器生成 .env（含随机 JWT_SECRET）
   - 手动补充 WECHAT_APPID 和 WECHAT_SECRET 到服务器 .env
5. 之后后端更新：GitHub Actions → Run workflow
```

**小程序 CI/CD 配置（一次性）：**
```
6. 微信公众平台 → 开发管理 → 开发设置 → 服务器域名 → 添加 https://{DOMAIN}
7. 微信公众平台 → 开发设置 → 小程序代码上传 → 生成密钥 → 下载 .key 文件
8. GitHub 仓库 Secrets 新增：WECHAT_APPID + WECHAT_PRIVATE_KEY
9. miniprogram/config/index.js 中确认 production.BASE_URL 正确
```

**小程序后续上传（每次更新）：**
```
GitHub 仓库 → Actions → Upload Miniprogram → Run workflow
→ 上传成功后，微信后台提交审核 → 审核通过后手动发布
```

> 审核和最终发布必须人工操作（微信平台限制，无法绕过）

---

# 最终汇报格式

```
✅ 小程序项目构建完成

📋 需求：[PRD 功能数量] 个功能，MVP 全部实现
🎨 设计：DESIGN_SYSTEM.md 已生成，variables.wxss 就绪
🔌 后端接口：[已实现] / [契约总数] 个，全部通过 QA
📱 小程序页面：[已实现] / [任务总数] 个，全部通过 QA
🗄️  数据库：[表数量] 张表，迁移机制就绪
🔒 安全：[高危/中危/低危]，高危全部修复
✅ 验收：reality-checker 判决 READY

📁 后端部署：走标准 app-deploy-agent 链路
📱 小程序上传：GitHub Actions → Upload Miniprogram → Run workflow（自动）
   审核发布：微信后台手动操作（平台限制，无法自动化）

⚠️ 上线前必须完成（人工）：
  - [ ] 服务器 .env 补充 WECHAT_APPID 和 WECHAT_SECRET
  - [ ] 微信后台添加合法域名：https://{DOMAIN}
  - [ ] miniprogram/config/index.js 确认 production.BASE_URL 正确
```
