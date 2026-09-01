# My OpenCode × DeepSeek Config

**简体中文** | [English](README.en-US.md)

**OpenCode × DeepSeek 最优配置** —— 在 OpenCode 多 Agent 框架下，将 DeepSeek V4 模型族（Pro + Flash + Flash-Vision）的能力发挥到极致的配置方案。核心理念：**Token 效率优先，用最小的上下文成本达到最好的开发效果**。

## 当前配置概览

- 默认主 Agent：`orchestrator`
- 主模型：`deepseek/deepseek-v4-pro`，轻量模型：`deepseek/deepseek-v4-flash`，多模态模型：`deepseek/deepseek-v4-flash-vision-exp`
- 代理层级：`subagent_depth: 3`（支持 3 级代理嵌套）
- 会话分享：关闭（`share: "disabled"`）
- 权限基线：默认放行，破坏性 bash 命令设为 `ask`；`.env` 类敏感文件 `deny`；外部目录 `ask`；只读 Agent 的 bash 白名单（默认 deny 全部 + 仅放行只读子命令）
- 上下文压缩：内置 compaction（opencode.jsonc）管自动触发 + prune 裁旧工具输出，DCP（dcp.jsonc）管主动去重 + 压缩阈值，两者互补
- 全局规则：`AGENTS.md`（核心原则、任务拒绝契约、自我验证、反模式等；上下文/Token 纪律在 `AGENTS.md`）
- 技能：`skills/` 目录下 **24 个** `SKILL.md` 技能，通过原生 `skill` 工具按需加载
- 插件：`superpowers`（git URL 固定 tag `#v6.3.0`，过程型技能）、`@tarquinen/opencode-dcp`（固定版本 `@3.1.15`，智能上下文裁剪）；两者均固定版本（pin）以保证字节稳定前缀、避免自动更新导致的前缀漂移

## DeepSeek 模型配置

### 前置条件

- OpenCode ≥ v1.18.x（DeepSeek provider 为内置）
- DeepSeek API Key：[platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 申请

### 方式一：TUI 交互式配置（推荐）

```bash
opencode
# 在 TUI 中输入: /connect → 选择 DeepSeek → 粘贴 API Key
# 然后: /models → 选择 deepseek-v4-pro
```

API Key 会自动持久化到 `~/.local/share/opencode/auth.json`。

### 方式二：环境变量

Windows PowerShell:
```powershell
$env:DEEPSEEK_API_KEY="sk-your-key-here"
opencode
```

永久设置：将 `DEEPSEEK_API_KEY` 添加到系统环境变量。

### Provider 配置参考

```jsonc
{
  "model": "deepseek/deepseek-v4-pro",
  "small_model": "deepseek/deepseek-v4-flash"
}
```

本配置在 `provider` 层拆分 thinking：flash 关闭 thinking 并固定 `temperature: 0`（最快最省），pro 保持默认（thinking 开启）。多模态 `deepseek-v4-flash-vision-exp` 同为 flash 档，沿用 flash 设置。示例（flash）：

```jsonc
"provider": {
  "deepseek": {
    "models": {
      "deepseek-v4-flash": {
        "options": {
          "temperature": 0,
          "thinking": { "type": "disabled" }
        }
      },
      "deepseek-v4-flash-vision-exp": {
        "options": {
          "temperature": 0,
          "thinking": { "type": "disabled" }
        }
      }
    }
  }
}
```

> **模型 ID 命名规则**：`provider_id/model_id`，即 `deepseek/deepseek-v4-pro`、`deepseek/deepseek-v4-flash` 和 `deepseek/deepseek-v4-flash-vision-exp`。

## 安装部署

### 方式一：克隆 + 环境变量（推荐，跨平台通用）

```bash
git clone https://github.com/znlgis/my-opencode-deepseek-config.git
```

然后将 `OPENCODE_CONFIG_DIR` 指向仓库内的 `opencode/` 子目录即可使用。

**Windows（PowerShell）** —— 永久生效：

```powershell
[Environment]::SetEnvironmentVariable("OPENCODE_CONFIG_DIR", "D:\path\to\my-opencode-deepseek-config\opencode", "User")
```

**Windows（PowerShell）** —— 临时生效（仅当前会话）：

```powershell
$env:OPENCODE_CONFIG_DIR = "D:\path\to\my-opencode-deepseek-config\opencode"
opencode
```

**Linux / macOS** —— 追加到 `~/.bashrc` 或 `~/.zshrc`：

```bash
export OPENCODE_CONFIG_DIR="$HOME/path/to/my-opencode-deepseek-config/opencode"
```

### 方式二：符号链接到全局配置目录

**Windows（PowerShell，需管理员）：**

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config"
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.config\opencode" -Target "D:\path\to\my-opencode-deepseek-config\opencode"
```

**Linux / macOS：**

```bash
ln -s /path/to/my-opencode-deepseek-config/opencode ~/.config/opencode
```

> **兼容性说明**：`~/.config/opencode` 是 OpenCode 的标准全局配置路径。本仓库的 `opencode/` 子目录内含 `agents/`、`skills/`、`AGENTS.md` 等文件，布局完全遵循 OpenCode 约定，通过环境变量或符号链接指向后即可被自动识别。

### 验证安装

启动 OpenCode 确认：
1. `/models` → 当前模型为 `deepseek/deepseek-v4-pro`
2. Agent 列表应能看到 `orchestrator`、`planner`、`deep-worker` 等 11 个 Agent
3. 输入任意请求，Orchestrator 自动分析意图并路由

## 模型分工

本仓库严格限制在 DeepSeek V4 模型族内分工，不引入其他模型：

| 模型 | 用途 |
| --- | --- |
| `deepseek/deepseek-v4-pro` | 深度推理、根因分析、代码审查、重型多文件实现 |
| `deepseek/deepseek-v4-flash` | 编排/路由、规划、常规实现、咨询、UI、探索、外部检索、轻量编辑、标题/摘要/压缩 |
| `deepseek/deepseek-v4-flash-vision-exp` | 多模态：图像/截图/图表/UI 稿的理解与描述 |

### 路由策略

- **Flash 优先**：路由、搜索、规划、常规实现、咨询、UI、探索等明确定义的任务优先走 flash agent
- **Vision 专责多模态**：检测到图像/截图/图表等视觉输入时，路由到 `vision` agent（flash-vision 模型）
- **Pro 专注推理**：深度推理、根因分析、代码审查、重型多文件实现——只用 pro
- **自动升级**：flash agent 无法胜任时自动升级到 pro（带完整上下文）

## Agent 结构

### Primary Agent

| Agent | 模型 | 作用 |
| --- | --- | --- |
| `orchestrator` | v4-flash | 默认入口：意图门控（Intent Gate）+ 模型感知路由 + 后备链 |

### Subagents

| Agent | 模型 | 权限 | 作用 |
| --- | --- | --- | --- |
| `planner` | v4-flash | 读写 | 规划、架构、拆解任务 |
| `deep-worker` | v4-pro | 读写 | 重型实现、多文件改动、复杂调试 |
| `oracle` | v4-pro | **只读** | 根因分析、深度理解代码 |
| `reviewer` | v4-pro | **只读** | 单遍代码审查（证据门控） |
| `ui-builder` | v4-flash | 读写 | 前端与 UI 相关任务 |
| `consultant` | v4-flash | 读写 | 方案讨论、最佳实践建议 |
| `explore` | v4-flash | **只读** | 代码库搜索、并行探索 |
| `librarian` | v4-flash | **只读** | 文档检索、Web 搜索 |
| `light-orchestrator` | v4-flash | 读写 | 轻量任务、单文件编辑 |
| `vision` | v4-flash-vision-exp | 读写 | 多模态：图像/截图/图表/UI 稿理解 |

> `deep-worker` 和 `light-orchestrator` 遵循"禁止研究、禁止委托"原则——执行而非探索，上下文由 orchestrator 提供。
>
> 只读 Agent（`oracle`/`reviewer`/`explore`/`librarian`）真只读化：`edit: deny` + bash 白名单（默认 deny 全部，仅放行 `git status/diff/log/show/blame/grep`、`rg` 等只读子命令；`oracle`/`reviewer` 另允许 `gh pr view/diff`、`gh issue view`、`gh api` 以支持 `/review-pr` 回帖）。

## 快捷命令

### Agent 路由命令

| 命令 | Agent | 用途 |
| --- | --- | --- |
| `/deep` | `deep-worker` | 重型实现、多文件改动 |
| `/quick` | `light-orchestrator` | 轻量任务、单文件编辑 |
| `/ui` | `ui-builder` | 前端/UI 工作 |
| `/vision` | `vision` | 多模态：图像/截图/图表理解 |
| `/review` | `reviewer`（code-review） | 轻量单遍审查 + 证据门控 |
| `/review-pr` | `reviewer`（code-review + gh-cli） | 审查 PR 并回帖到 GitHub |
| `/plan` | `planner` | 制定计划、技术方案 |
| `/search` | `librarian` | 外部搜索、查文档 |
| `/oracle` | `oracle` | 深度分析、问题溯源 |
| `/consult` | `consultant` | 咨询、对比、建议 |

### 操作命令

| 命令 | Agent | 用途 |
| --- | --- | --- |
| `/commit` | `light-orchestrator` | 生成 Conventional Commits 提交信息（内联格式） |
| `/release` | `deep-worker`（git-release） | 准备 Tag 发布 |
| `/reflect` | `oracle`（reflect） | 发现摩擦 → 提出配置优化 |
| `/handoff` | `light-orchestrator`（handoff） | 压缩会话为交接文档 |

### 内联命令

| 命令 | Agent | 用途 |
| --- | --- | --- |
| `/codemap` | `explore`（codemap） | 生成仓库结构图 |
| `/learn` | `light-orchestrator` | 把会话中的非显然经验沉淀到目录级 AGENTS.md（根/包/特性级） |
| `/simplify` | `light-orchestrator`（simplify）→ spawn `oracle` | spawn oracle 只读分析 → light-orchestrator 应用编辑 |
| `/rmslop` | `deep-worker`（remove-deadcode） | 清理死代码和 AI slop |

### 规约命令

| 命令 | Agent | 用途 |
| --- | --- | --- |
| `/spec-propose` | `planner`（spec-workflow） | 探索代码 → 起草变更提案 |
| `/spec-apply` | `deep-worker`（spec-workflow） | 按 tasks.md 逐一实现 → 自动归档 |

## 技能（Skills）

OpenCode 通过原生 `skill` 工具按需暴露技能——Agent 只在需要时才加载，不占用上下文。

| Skill | 作用 |
| --- | --- |
| `code-review` | 单遍代码审查 + 证据门控；大 diff（>~500 行）拆 Standards/Spec 两轴合并报告 |
| `codemap` | 生成带标注的仓库结构图，快速定向，节省探索 token |
| `gh-cli` | GitHub CLI v2.98+ 参考：PR 回帖、api、rate limit、gh pr checks、gh skill/gh-aw、GHSA 安全要点 |
| `git-master` | 高级 Git 操作：rebase、squash、fixup、bisect、reflog、代码考古、worktree |
| `git-release` | Tag 发布：发布说明、SemVer 推断、gh release 命令 |
| `resolving-merge-conflicts` | 逐 hunk 解析合并冲突：追溯原始意图、永不发明新行为、永不 --abort |
| `handoff` | 压缩会话为交接文档（路径引用，不复制内容） |
| `opencode-config` | 编写和维护本仓库 OpenCode 配置（agents/skills/commands/permissions） |
| `reflect` | 持续改进：发现摩擦 → 提出最小可维护修复 |
| `remove-deadcode` | 安全查找并删除死代码，删除前经工具链/LSP 验证 |
| `security-review` | 合并前安全审查（注入/XSS/SSRF/密钥/反序列化/路径穿越），只报不改 |
| `shared-language` | 构建领域术语表（CONTEXT.md），大幅节省 token |
| `simplify` | 行为保持的代码简化（oracle 分析 → 应用） |
| `spec-workflow` | 轻量规约驱动变更：proposal → delta specs → tasks → update 三问决策树 → verify → archive |
| `prototype` | 一次性原型回答设计问题：逻辑问题→单 HTML 交互演示；UI 问题→同路由多样式变体；当天一次性、一键可跑、无持久化 |
| `wayfinder` | 超大工程迷雾期导航：decision-ticket 地图（research/prototype/grilling/task 四类 + blocking edges + frontier），本地 Markdown tracker，一次会话解析一个 ticket |
| `verify-with-docs` | 编码前核对 API 文档，检索优先，防幻觉 |
| `grilling` | 需求对齐访谈：一次一问、多选优先，歧义收敛后再动手 |
| `tech-debt-audit` | 9 维度技术债审计（死代码/重复/命名漂移/复杂度/依赖/错误处理/测试/文档/安全），只读报告不改码 |
| `wait-what` | 用户消息难懂时先一句话重述确认，再动手 |
| `writing-for-agents` | 写给 agent 看的文档（skill/AGENTS.md/指针文档）的写作杠杆 |
| `to-questionnaire` | 离通道一次性问卷（异步填写），区别于 grilling 的实时访谈 |
| `research` | 开放课题深调研，产出带引用的 Markdown，区别于 verify-with-docs 的单点核对 |
| `wizard` | 人工逐步向导（bash 脚本，`bash -n` 验证），引导人类完成自身才能做的步骤 |

## 设计决策与迭代记录

核心思路借鉴了 [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)（意图门控、只读隔离、反模式）、[oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim)（调度器优先、后备链、拒绝契约、提示词缓存安全、impact×confidence÷cost）、[anomalyco/opencode](https://github.com/anomalyco/opencode)（配置 Schema、技能体系）、[cli/cli](https://github.com/cli/cli)（gh v2.98 命令集、rate limit、gh-aw）、[OpenSpec](https://github.com/Fission-AI/OpenSpec)（delta specs、OPSX 动作流 update/verify/四问）、[mattpocock/skills](https://github.com/mattpocock/skills)（冲突解析纪律、交接文档）、[pi](https://github.com/earendil-works/pi)（先答后改、精简响应、独立会话收集）和 [deepreview](https://github.com/mechanai/deepreview)（有效大小路由）的优点，纯配置实现，零额外依赖。

> **借鉴而非照搬**：过重的流水线只汲取轻量化设计理念；冗余功能由现有 agents/skills 覆盖，不新增。遵循"精简优先于新增"原则，每次迭代都以净减 token 为目标。
>
> **本轮（v37）机制来源**：`/learn` 命令（目录级 AGENTS.md 经验沉淀）、`references` 挂载 deepseek-harness（官方模型配置指引）、orchestrator `permission.task` 白名单（`"*":"deny"` + 10 子代理 allow）、gh-cli 版本对齐 v2.98、opencode-config 三模型约束、dcp.jsonc 1M 窗口修正——均借鉴 [anomalyco/opencode](https://github.com/anomalyco/opencode) 与 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)。
>
> **评估后未采用**：mattpocock 的 issue-tracker 工作流（to-spec/to-tickets/triage/implement）过重；omo 的分类路由与按模型族定制提示词，对 3 模型纯配置而言过度设计；diagnosing-bugs 与 superpowers 的 systematic-debugging 重叠，未新增；superpowers 无配置旋钮，保持插件字符串形式注入；opencode@dev 的 effect/rtl-aware-development 技能与 triage/duplicate-pr agent 为仓库专属，需专用 GitHub 工具，未引入。

### 迭代里程碑

自 v1 以来历经 37 次迭代，持续对标上游仓库最佳实践：

> **展示规则**：仅保留最新 5 个版本（v33-v37）的独立更新说明；更早版本按每 10 个版本合并为一条描述（v1-v10、v11-v20、v21-v32）。每次新增版本时，将最旧的独立版本并入其对应的 10 版本区间，保持此结构。

- **v1-v10（奠基 + 审查/规约/契约）**：双模型绑定、Agent 角色体系、意图门控路由、AGENTS.md 全局规则、Skills 目录、权限基线；code-review 双轴校准、spec-workflow、gh-cli 对齐、拒绝契约、后台核查
- **v11-v20（持续瘦身）**：命令 29→18（-38%）、AGENTS.md 290→211（-27%）、逐句 no-op 修剪、Schema 校验去死键
- **v21-v32（对齐 + 安全 + 纪律重构 + 会话复盘）**：整合 6 个上游仓库、gh-cli v2.97 转义注入安全章节、DCP 窗口调优；prune/DCP 百分比阈值收紧、grilling 引入、code-review 单遍化 + 证据门控、provider 层 thinking 拆分、缓存纪律、scope-first + 委派优先、原子 TODO、5 新技能至 24 个、README 双语同步；v31 新增多模态模型 vision-exp、vision agent 与 /vision 命令；v32 会话复盘优化（P0 子代理空结果降级、P1 orchestrator 上下文卫生+路由表补全、P2 技能修正+全项目审查+Git 安全禁目录级 add）
- **v33（质量完善）**：修复 opencode.jsonc 尾随逗号；新增 .gitignore；增强 research 技能（18→78 行）；修正 orchestrator 路由表三处不一致（refactor 路由 oracle→deep-worker、simplify 路由明确 light-orchestrator、deploy/release 对齐 /release 命令）；spec-workflow 格式修补；opencode-config 技能增补 validate-jsonc.js 引用；simplify 命令模板明确 writer agent；新增 scripts/validate-jsonc.js 字符串感知校验器
- **v34（定向瘦身 + 高价值借鉴）**：handoff 增 pi 结构化标题（Goal / Constraints & Preferences / Progress / Key Decisions / Next Steps / Critical Context）；shared-language 增"术语表即一切"与 ADR 分流规则（mattpocock）；gh-cli 增次级限流检测；opencode.jsonc thinking 注释修正为 provider 透传说明；README 修正快照（snapshot）过期声明、命令数核实为 19 条无误；核实两轴审查/delta specs/缓存纪律等上游理念已落地，未新增技能
- **v35（借鉴 opencode@dev + 版本对齐）**：新增 `/learn` 命令（目录级 AGENTS.md 经验沉淀，借鉴 opencode@dev learn.md）；新增 `deepseek-harness` references 挂载（官方模型配置指引）；orchestrator 增 `permission.task` 白名单（`"*":"deny"` + 10 子代理 allow，借鉴 opencode@dev 单工具 agent 模式）；gh-cli 技能版本 v2.97→v2.98 对齐；opencode-config 技能模型约束更新为三模型（含 vision-exp）；dcp.jsonc 修正 128K→1M 窗口注释；命令数 19→20
- **v36（对标 5 仓库 + 插件固定版本）**：综合 oh-my-openagent / OpenSpec / oh-my-opencode-slim / pi / deepseek-harness 五仓库调研，确认多数省钱与轻量审查理念已内化（thinking 拆分、字节稳定前缀、tool 裁剪、compaction 双层、findings 分级+证据、verdict 聚合、反模式表、review 不与编辑并行），仅补增量：AGENTS.md 增循环检测（连续 3+ 次相同工具调用视为空转，防 token 空转，借鉴 deepseek-harness repeat-tool-reminder）；code-review 增 2 条显式反模式（串行 spawn→CRITICAL、不读文件下结论→HIGH）；gh-cli 增 v2.98+ 命令（`--search-type semantic`、issue 类型/子 issue/关系、`--attach` 附件、`gh repo read-file/read-dir`、`gh skill publish`、`GH_FORCE_TTY`）；插件固定版本（superpowers `#v6.3.0`、DCP `@3.1.15`、`autoUpdate:false`）以保字节稳定前缀；README 结构图 dcp.jsonc 注释修正为绝对 token 阈值 77K/38K
- **v37（三方审计修复）**：修复 validate-jsonc.js 尾随逗号正则（数组尾随逗号误报 INVALID）；opencode.jsonc DCP 注释对齐绝对阈值 77K/38K；/simplify 命令改为 light-orchestrator 两段式（spawn oracle 只读分析 → 应用编辑）；五个 writer agent 硬化禁止委托（permission.task deny）+ light-orchestrator 窄授权（仅 oracle allow）；dcp.jsonc 移除未 pin 的 master $schema（插件 3.1.15 无稳定 tag schema，键名已核验）；AGENTS.md 循环检测规则译为英文并移至反模式节；orchestrator.md 三处逐字重复压缩为指针引用；核验 superpowers 插件无 prototype 同名技能，仓库副本非重复，保留；README 迭代计数 34→37、展示区间 v31-v35→v33-v37、v31/v32 并入折叠组（v21-v32）；删除重复的 /oracle 映射行

## 仓库结构

```text
├── opencode/                     # OpenCode 配置目录（可独立部署）
│   ├── agents/                   # 11 个专职 Agent
│   │   ├── orchestrator.md       # 主入口：意图门控 + 模型感知路由
│   │   ├── planner.md            # flash：架构与规划
│   │   ├── deep-worker.md        # pro：重型实现
│   │   ├── oracle.md             # pro：深度代码分析（只读）
│   │   ├── reviewer.md           # pro：单遍代码审查（只读）
│   │   ├── consultant.md         # flash：方案讨论与建议
│   │   ├── ui-builder.md         # flash：前端与 UI
│   │   ├── explore.md            # flash：代码库搜索（只读）
│   │   ├── librarian.md          # flash：外部检索（只读）
│   │   ├── light-orchestrator.md # flash：简单编辑
│   │   └── vision.md             # flash-vision：多模态理解
│   ├── skills/                   # 24 个按需加载技能
│   │   ├── code-review/          # 轻量单遍审查 + 证据门控
│   │   ├── codemap/              # 生成仓库结构图
│   │   ├── gh-cli/               # GitHub CLI v2.98+ 参考 + 安全警告
│   │   ├── git-master/           # 高级 Git 操作
│   │   ├── git-release/          # Tag 发布
│   │   ├── handoff/              # 会话压缩为交接文档
│   │   ├── opencode-config/      # 元技能：本仓库配置编写
│   │   ├── reflect/              # 持续改进
│   │   ├── remove-deadcode/      # 死代码检测与删除
│   │   ├── resolving-merge-conflicts/ # 逐 hunk 冲突解析纪律
│   │   ├── security-review/      # 安全审查清单
│   │   ├── shared-language/      # 领域术语表（节省 token）
│   │   ├── simplify/             # 行为保持的代码简化
│   │   ├── spec-workflow/        # 规约驱动开发
│   │   ├── tech-debt-audit/      # 技术债审计（9 维度，只读报告）
│   │   ├── prototype/            # 一次性原型回答设计问题
│   │   ├── wayfinder/            # 超大工程迷雾期导航
│   │   ├── verify-with-docs/     # 检索优先 API 验证
│   │   ├── grilling/             # 需求对齐访谈
│   │   ├── research/             # 开放课题深调研（带引用）
│   │   ├── to-questionnaire/     # 离通道一次性问卷
│   │   ├── wait-what/            # 难懂消息先一句话重述确认
│   │   ├── wizard/               # 人工逐步向导（bash -n 验证）
│   │   └── writing-for-agents/   # 面向 agent 的文档写作
│   ├── opencode.jsonc            # 主配置（20 条命令）
│   ├── AGENTS.md                 # 全局规则
│   └── dcp.jsonc                 # DCP 上下文压缩（DeepSeek V4 1M，绝对 token 阈值 77K/38K）
├── README.md
├── README.en-US.md
└── LICENSE
```

## 使用指南

### 模式一：Orchestrator 自动路由（默认）

用自然语言描述需求，Orchestrator 自动分析意图、选择最合适的 Agent 和模型执行。

```text
「帮我排查这个登录接口的报错」     → oracle 分析根因 → 返回诊断报告
「优化这段循环，性能太差了」         → oracle 分析 → deep-worker 实施优化
「这个 PR 帮我审查一下」             → reviewer 多维度审查 → 返回分级报告
「我想给用户模块加个导出功能」       → planner 制定方案 → deep-worker 实现
「React 19 的 use() API 怎么用」    → librarian 查文档 → 返回签名和示例
```

### 模式二：命令别名直达

| 场景 | 命令 |
| --- | --- |
| 复杂实现 / 多文件改动 | `/deep` |
| 轻量修改 / 单文件编辑 | `/quick` |
| 制定技术方案 / 架构设计 | `/plan` |
| 排查 Bug / 深度分析 | `/oracle` |
| 代码审查 | `/review` |
| 外部搜索 / 查 API | `/search` |
| 前端 / UI 工作 | `/ui` |
| 多模态 / 图像理解 | `/vision` |
| 方案讨论 / 对比取舍 | `/consult` |

### 典型工作流

**开发新功能（规约驱动）：**
```text
/spec-propose  → /spec-apply  → /review
```

**排查 Bug：**
```text
/oracle  → /deep  → /rmslop  → /commit
```

**代码审查：**
```text
/review-pr   ← 审查 PR + 自动回帖
/review      ← 轻量单遍审查
```

## 设计哲学

- **纯配置驱动，零额外依赖** —— 所有能力由 `opencode.jsonc` + `agents/*.md` + `skills/*/SKILL.md` + `AGENTS.md` 实现
- **DeepSeek V4 模型族极致利用** —— Pro 做深度推理与重型实现，Flash 做路由、规划与常规执行，Flash-Vision 专责多模态
- **Token 效率优先** —— 路径引用替代粘贴文件、技能按需加载、压缩分级管理
- **插件增效但不喧宾夺主** —— superpowers 提供过程纪律，DCP（dcp.jsonc）主动去重+压缩阈值，内置 compaction（opencode.jsonc）自动触发+prune 兜底；两插件均固定版本（pin）以保字节稳定前缀，避免自动更新导致前缀漂移
- **执行与探索分离** —— deep-worker/light-orchestrator 禁止研究/委托，explore/librarian 禁止修改
- **缓存与 thinking 纪律** —— 静态前缀稳定以命中 DeepSeek 提示词缓存；flash 关 thinking + temperature 0（provider 层），pro 默认 thinking 开
- **Scope First + Delegate Always** —— 先定范围（2+ 步/多文件/架构变更先走 planner），再委派执行，顶层 token 只留给路由与难题
- **原子 TODO** —— 多步任务先写有序 TODO，逐条 in_progress→completed；格式 `path: action for scenario — verify by check`
- **持续改进** —— reflect 机制化发现摩擦、code-review 证据门控保证质量
