# 微信小程序开发团队（Claude Code）

一套面向 **微信小程序 + 后端** 的 Claude Code Subagent 团队。从需求到可交付代码，按 11 个阶段契约驱动，每个任务实现后立即 QA 验证。

> 这是「标准开发团队」的小程序特化版：后端走标准开发链路，前端换成小程序专属的设计/开发 agent，并补齐微信登录、隐私合规、小程序 CI/CD 上传等环节。

---

## 它能做什么

输入一句「用小程序团队开发一个 XXX」，主对话作为总指挥，自动按顺序调度成员 agent：

```
需求分析 → 技术架构/API 契约 → 小程序设计规范 → 任务拆解
→ 数据库 → 后端实现(含微信登录) → 小程序页面实现
→ 安全审查(含封号高风险项) → 代码 Review → DevOps/CI-CD → 验收 → 文档
```

产出是**可交付代码**：后端走标准部署链路上线，小程序端代码通过 GitHub Actions 自动上传到微信后台（审核/发布需人工，平台限制无法绕过）。

---

## 安装

### 一键安装（推荐）

```bash
git clone https://github.com/xuanbingbingo/claude-miniprogram-team.git
cd claude-miniprogram-team
bash install.sh
```

脚本会**自动检测你是否已经装过「标准开发团队」**：

| 你的情况 | 安装行为 |
|---|---|
| 没装过标准团队 | 安装全部 16 个 agent，开箱即用 |
| 已装过标准团队 | 只补 3 个小程序专属 agent；共用 agent 保持你现有版本，**不覆盖** |

其他用法：

```bash
bash install.sh --force       # 强制覆盖所有同名 agent（用最新版）
bash install.sh --uninstall   # 卸载（只删专属 agent + skill，不动共用 agent）
```

### 验证

```bash
ls ~/.claude/agents/ | grep miniprogram      # 应看到 3 个 miniprogram-* agent
ls ~/.claude/skills/miniprogram-team/SKILL.md
```

重启 Claude Code，新开对话输入：

```
用小程序团队开发一个图书借阅小程序
```

主对话会 load `miniprogram-team` skill 并按 11 阶段接管，先调 product-manager 写 PRD，等你确认范围后继续。

---

## 与标准团队的关系

这套团队 = **3 个小程序专属 agent** + **13 个与标准团队共用的 agent**。

**专属 agent（本仓库核心）：**

| Agent | 职责 | 对应标准团队的谁 |
|---|---|---|
| `miniprogram-developer` | 小程序页面/组件（uni-app / 原生 / Taro） | 替代 frontend-developer |
| `miniprogram-ui-designer` | 小程序设计规范、variables.wxss（rpx 单位） | 替代 ui-designer |
| `miniprogram-orchestrator` | 退役兼容入口（真正总指挥是 skill） | 对应 orchestrator |

**共用 agent（自动包含，省得你两个仓库来回装）：**

product-manager / software-architect / database-optimizer / backend-architect / devops-automator / testing-evidence-collector / security-engineer / code-reviewer / reality-checker / technical-writer / app-deploy-agent / infra-bootstrap-agent / deploy-yaml-schema

> 如果你之后也装标准团队，`install.sh` 不会重复覆盖这些共用 agent。

---

## 跟标准团队比，多了什么

| 维度 | 标准团队 | 小程序团队 |
|---|---|---|
| 前端实现 | frontend-developer（Vue/React/Next） | miniprogram-developer（uni-app/原生/Taro） |
| 样式单位 | px / rem / CSS 变量 | rpx / WXSS 变量（page{} 内） |
| 请求方式 | axios/fetch + 相对路径 | wx.request + utils/request.js 封装 |
| 后端登录 | 自定义 | 额外实现 `/api/wx/login`（code 换 openid + JWT） |
| 安全审查 | 标准项 | 额外查微信封号高风险项（隐私协议/鉴权/CORS/限流） |
| 前端容器 | 有（nginx 静态服务） | 无（小程序无需前端容器） |
| 发布 | 自动生效 | GitHub Actions 上传 → 微信后台人工审核发布 |
| 域名 | 可用 IP | **必须 HTTPS 域名**（微信硬要求） |

---

## 完整流程文档

每个阶段的详细输入/产出/打回规则，见 [`skills/miniprogram-team/SKILL.md`](skills/miniprogram-team/SKILL.md)（这也是主对话实际加载的总指挥剧本）。

---

## 常见问题

**Q：和标准团队能同时装吗？**
能。共用 agent 只有一份，两套 skill 各自独立，互不冲突。

**Q：为什么总指挥是 skill 不是 agent？**
Claude Code 平台限制——subagent 不能再 spawn subagent。所以总指挥必须由主对话亲自担任，以 skill 形式装载剧本。`miniprogram-orchestrator.md` 仅作老用户兼容入口保留。

**Q：能在 Cursor / Cline 用吗？**
不能。依赖 Claude Code 的 Subagents 机制。

**Q：审核发布能自动化吗？**
不能。代码上传可以自动（miniprogram-ci），但提交审核和正式发布是微信平台的人工环节，无法绕过。

---

## License

MIT
