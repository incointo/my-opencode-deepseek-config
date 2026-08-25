# My OpenCode × DeepSeek Config

[简体中文](README.md) | **English**

**OpenCode × DeepSeek Optimal Config** — a configuration scheme that pushes the DeepSeek V4 model family (Pro + Flash + Flash-Vision) to its full potential within OpenCode's multi-agent framework. Core philosophy: **token efficiency first — the best development results at the lowest context cost**.

## Current Configuration Overview

- Default primary agent: `orchestrator`
- Primary model: `deepseek/deepseek-v4-pro`; lightweight model: `deepseek/deepseek-v4-flash`; multimodal model: `deepseek/deepseek-v4-flash-vision-exp`
- Agent nesting: `subagent_depth: 3` (supports 3 levels of subagent nesting)
- Session sharing: off (`share: "disabled"`)
- Permission baseline: allow by default, destructive bash commands set to `ask`; sensitive `.env`-type files `deny`; external directories `ask`; read-only agents get a bash allowlist (deny all by default + allow read-only subcommands only)
- Context compression: built-in compaction (opencode.jsonc) handles auto-triggering + pruning of stale tool output; DCP (dcp.jsonc) handles proactive dedup + compression thresholds — the two complement each other
- Global rules: `AGENTS.md` (core principles, task rejection contract, self-verification, anti-patterns, etc.; context/token discipline in `AGENTS.md`)
- Skills: **24** `SKILL.md` skills under `skills/`, loaded on demand via the native `skill` tool
- Plugins: `superpowers` (git URL tracking main branch, process skills), `@tarquinen/opencode-dcp` (intelligent context pruning)

## DeepSeek Model Configuration

### Prerequisites

- OpenCode ≥ v1.18.x (the DeepSeek provider is built in)
- DeepSeek API key: request one at [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys)

### Option 1: Interactive TUI Setup (Recommended)

```bash
opencode
# In TUI enter: /connect → select DeepSeek → paste API Key
# Then: /models → select deepseek-v4-pro
```

The API key is automatically persisted to `~/.local/share/opencode/auth.json`.

### Option 2: Environment Variable

Windows PowerShell:
```powershell
$env:DEEPSEEK_API_KEY="sk-your-key-here"
opencode
```

Permanent setup: add `DEEPSEEK_API_KEY` to your system environment variables.

### Provider Configuration Reference

```jsonc
{
  "model": "deepseek/deepseek-v4-pro",
  "small_model": "deepseek/deepseek-v4-flash"
}
```

This config splits thinking at the `provider` layer: flash disables thinking and pins `temperature: 0` (fastest, cheapest), while pro keeps the default (thinking on). The multimodal `deepseek-v4-flash-vision-exp` is flash-tier and mirrors flash's settings. Example (flash):

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

> **Model ID naming convention**: `provider_id/model_id` — i.e. `deepseek/deepseek-v4-pro`, `deepseek/deepseek-v4-flash`, and `deepseek/deepseek-v4-flash-vision-exp`.

## Installation

### Option 1: Clone + Environment Variable (Recommended, Cross-Platform)

```bash
git clone https://github.com/znlgis/my-opencode-deepseek-config.git
```

Then point `OPENCODE_CONFIG_DIR` at the `opencode/` subdirectory in the repo and you're ready to go.

**Windows (PowerShell)** — permanent:

```powershell
[Environment]::SetEnvironmentVariable("OPENCODE_CONFIG_DIR", "D:\path\to\my-opencode-deepseek-config\opencode", "User")
```

**Windows (PowerShell)** — temporary (current session only):

```powershell
$env:OPENCODE_CONFIG_DIR = "D:\path\to\my-opencode-deepseek-config\opencode"
opencode
```

**Linux / macOS** — append to `~/.bashrc` or `~/.zshrc`:

```bash
export OPENCODE_CONFIG_DIR="$HOME/path/to/my-opencode-deepseek-config/opencode"
```

### Option 2: Symlink to the Global Config Directory

**Windows (PowerShell, admin required):**

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config"
New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\.config\opencode" -Target "D:\path\to\my-opencode-deepseek-config\opencode"
```

**Linux / macOS:**

```bash
ln -s /path/to/my-opencode-deepseek-config/opencode ~/.config/opencode
```

> **Compatibility note**: `~/.config/opencode` is OpenCode's standard global config path. The `opencode/` subdirectory in this repo contains `agents/`, `skills/`, `AGENTS.md`, and more, and follows OpenCode's layout conventions exactly — point to it via environment variable or symlink and it is picked up automatically.

### Verify the Installation

Launch OpenCode and confirm:
1. `/models` → the current model is `deepseek/deepseek-v4-pro`
2. The agent list shows all 11 agents, including `orchestrator`, `planner`, and `deep-worker`
3. Send any request — the Orchestrator analyzes intent and routes automatically

## Model Division of Labor

This repo strictly divides work within the DeepSeek V4 model family — no other models are introduced:

| Model | Purpose |
| --- | --- |
| `deepseek/deepseek-v4-pro` | Deep reasoning, root-cause analysis, code review, heavy multi-file implementation |
| `deepseek/deepseek-v4-flash` | Orchestration/routing, planning, routine implementation, consultation, UI, exploration, external lookup, light edits, title/summary/compaction |
| `deepseek/deepseek-v4-flash-vision-exp` | Multimodal: understanding and describing images, screenshots, charts, and UI mockups |

### Routing Strategy

- **Flash first**: well-defined tasks — routing, search, planning, routine implementation, consultation, UI, exploration — go to flash agents first
- **Vision owns multimodal**: when visual input (images, screenshots, charts) is detected, route to the `vision` agent (flash-vision model)
- **Pro reserved for reasoning**: deep reasoning, root-cause analysis, code review, heavy multi-file implementation — pro only
- **Automatic escalation**: when a flash agent can't handle a task, it escalates to pro automatically (with full context)

## Agent Structure

### Primary Agent

| Agent | Model | Role |
| --- | --- | --- |
| `orchestrator` | v4-flash | Default entry point: intent gate + model-aware routing + fallback chains |

### Subagents

| Agent | Model | Permission | Role |
| --- | --- | --- | --- |
| `planner` | v4-flash | read-write | Planning, architecture, task breakdown |
| `deep-worker` | v4-pro | read-write | Heavy implementation, multi-file changes, complex debugging |
| `oracle` | v4-pro | **read-only** | Root-cause analysis, deep code understanding |
| `reviewer` | v4-pro | **read-only** | Single-pass code review (evidence-gated) |
| `ui-builder` | v4-flash | read-write | Frontend and UI tasks |
| `consultant` | v4-flash | read-write | Approach discussions, best-practice advice |
| `explore` | v4-flash | **read-only** | Codebase search, parallel exploration |
| `librarian` | v4-flash | **read-only** | Documentation lookup, web search |
| `light-orchestrator` | v4-flash | read-write | Lightweight tasks, single-file edits |
| `vision` | v4-flash-vision-exp | read-write | Multimodal: images/screenshots/charts/UI mockups |

> `deep-worker` and `light-orchestrator` follow a "no research, no delegation" principle — they execute, not explore; context is provided by the orchestrator.
>
> Read-only agents (`oracle`/`reviewer`/`explore`/`librarian`) are truly read-only: `edit: deny` + a bash allowlist (deny all by default, allow only read-only subcommands such as `git status/diff/log/show/blame/grep` and `rg`; `oracle`/`reviewer` additionally allow `gh pr view/diff`, `gh issue view`, and `gh api` to support `/review-pr` replies).

## Quick Commands

### Agent Routing Commands

| Command | Agent | Purpose |
| --- | --- | --- |
| `/deep` | `deep-worker` | Heavy implementation, multi-file changes |
| `/quick` | `light-orchestrator` | Lightweight tasks, single-file edits |
| `/ui` | `ui-builder` | Frontend/UI work |
| `/vision` | `vision` | Multimodal: image/screenshot/chart understanding |
| `/review` | `reviewer` (code-review) | Lightweight single-pass review + evidence gating |
| `/review-pr` | `reviewer` (code-review + gh-cli) | Review a PR and post the result to GitHub |
| `/plan` | `planner` | Create plans and technical proposals |
| `/search` | `librarian` | External search, documentation lookup |
| `/oracle` | `oracle` | Deep analysis, root-cause tracing |
| `/consult` | `consultant` | Consulting, comparisons, recommendations |

### Operation Commands

| Command | Agent | Purpose |
| --- | --- | --- |
| `/commit` | `light-orchestrator` | Generate Conventional Commits messages (inline format) |
| `/release` | `deep-worker` (git-release) | Prepare a tagged release |
| `/reflect` | `oracle` (reflect) | Surface friction → propose config improvements |
| `/handoff` | `light-orchestrator` (handoff) | Compress the session into a handoff document |

### Inline Commands

| Command | Agent | Purpose |
| --- | --- | --- |
| `/codemap` | `explore` (codemap) | Generate a repository structure map |
| `/learn` | `light-orchestrator` | Distill non-obvious session learnings into directory-level AGENTS.md files (root/package/feature) |
| `/simplify` | `oracle` (simplify) → `light-orchestrator` | oracle analyzes → light-orchestrator applies the simplifications |
| `/rmslop` | `deep-worker` (remove-deadcode) | Clean up dead code and AI slop |

### Spec Commands

| Command | Agent | Purpose |
| --- | --- | --- |
| `/spec-propose` | `planner` (spec-workflow) | Explore the code → draft a change proposal |
| `/spec-apply` | `deep-worker` (spec-workflow) | Implement item by item per tasks.md → auto-archive |

## Skills

OpenCode exposes skills on demand via the native `skill` tool — agents load them only when needed, so they never occupy context.

| Skill | Purpose |
| --- | --- |
| `code-review` | Single-pass code review + evidence gating; large diffs (>~500 lines) split into Standards/Spec two axes merged into one report |
| `codemap` | Generates an annotated repository structure map for quick orientation, saving exploration tokens |
| `gh-cli` | GitHub CLI v2.98+ reference: PR posting, api, rate limits, gh pr checks, gh skill/gh-aw, GHSA security notes |
| `git-master` | Advanced Git operations: rebase, squash, fixup, bisect, reflog, code archaeology, worktrees |
| `git-release` | Tagged releases: release notes, SemVer inference, gh release commands |
| `resolving-merge-conflicts` | Resolve merge conflicts hunk by hunk: trace original intent, never invent new behavior, never --abort |
| `handoff` | Compresses a session into a handoff document (path references, no copied content) |
| `opencode-config` | Writes and maintains OpenCode config in this repo (agents/skills/commands/permissions) |
| `reflect` | Continuous improvement: surface friction → propose minimal, maintainable fixes |
| `remove-deadcode` | Safely finds and deletes dead code, verified via toolchain/LSP before removal |
| `security-review` | Pre-merge security review (injection/XSS/SSRF/secrets/deserialization/path traversal); reports, never auto-fixes |
| `shared-language` | Builds a domain glossary (CONTEXT.md), saving significant tokens |
| `simplify` | Behavior-preserving code simplification (oracle analyzes → applied) |
| `spec-workflow` | Lightweight spec-driven change: proposal → delta specs → tasks → update three-question decision tree → verify → archive |
| `prototype` | Throwaway prototype to answer a design question: logic → single HTML interactive demo; UI → multiple style variants on one route; one-day, one-command, no persistence |
| `wayfinder` | Fog-of-war navigation for huge codebases: decision-ticket map (research/prototype/grilling/task kinds + blocking edges + frontier), local Markdown tracker, one ticket per session |
| `verify-with-docs` | Verifies API docs before coding — retrieval-first, hallucination-proof |
| `grilling` | Requirements-alignment interview: one question at a time, multiple choice preferred, converge on ambiguity before acting |
| `tech-debt-audit` | 9-dimension tech debt audit (dead code/duplication/naming drift/complexity/dependencies/error handling/tests/docs/security); read-only report, no code changes |
| `wait-what` | Restates hard-to-parse user messages in one sentence for confirmation before acting |
| `writing-for-agents` | Writing leverage for agent-facing docs (skills/AGENTS.md/pointer docs) |
| `to-questionnaire` | Off-channel one-shot questionnaire (filled in asynchronously), distinct from grilling's live interview |
| `research` | Deep research on open topics, producing cited Markdown, distinct from verify-with-docs single-point checks |
| `wizard` | Human step-by-step wizard (bash script, `bash -n` verified), guides humans through steps only they can perform |

## Design Decisions & Iteration Log

The core ideas draw on [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) (intent gating, read-only isolation, anti-patterns), [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim) (dispatcher-first, fallback chains, rejection contract, prompt-cache safety, impact×confidence÷cost), [anomalyco/opencode](https://github.com/anomalyco/opencode) (config schema, skill system), [cli/cli](https://github.com/cli/cli) (gh v2.98 command set, rate limits, gh-aw), [OpenSpec](https://github.com/Fission-AI/OpenSpec) (delta specs, OPSX action flow update/verify/four questions), [mattpocock/skills](https://github.com/mattpocock/skills) (conflict resolution discipline, handoff documents), [pi](https://github.com/earendil-works/pi) (answer first then act, terse responses, independent session collection), and [deepreview](https://github.com/mechanai/deepreview) (effective-size routing) — pure config, zero extra dependencies.

> **Borrow, don't copy**: from heavyweight pipelines we take only lightweight design ideas; redundant features are covered by existing agents/skills, so nothing new is added. Following the "simplify before adding" principle, every iteration targets net token reduction.
>
> **This round (v35) — mechanism sources**: the `/learn` command (directory-level AGENTS.md learning distillation), `references` mounting deepseek-harness (official model-config guidance), orchestrator `permission.task` allowlist (`"*":"deny"` + 10 subagents allow), gh-cli version alignment to v2.98, opencode-config three-model constraint, dcp.jsonc 1M-window fix — all borrowed from [anomalyco/opencode](https://github.com/anomalyco/opencode) and [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness).
>
> **Evaluated and rejected**: mattpocock's issue-tracker workflow (to-spec/to-tickets/triage/implement) is too heavy; omo's category-based routing and model-family-specific prompts are over-engineering for a 3-model pure-config setup; diagnosing-bugs overlaps superpowers' systematic-debugging; superpowers has no config knobs, so it remains injected as a plugin string; opencode@dev's effect/rtl-aware-development skills and triage/duplicate-pr agents are repo-specific and need dedicated GitHub tools, so they were not adopted.

### Iteration Milestones

34 iterations since v1, continuously benchmarking best practices from upstream repositories:

> **Display rule**: keep only the latest 5 versions (v31-v35) as individual update notes; merge earlier versions into one description per 10-version range (v1-v10, v11-v20, v21-v30). When adding a new version, fold the oldest individual version into its corresponding 10-version range to maintain this structure.

- **v1-v10 (foundation + review/specs/contract)**: dual-model binding, agent role system, intent-gate routing, AGENTS.md global rules, skills directory, permission baseline; code-review two-axis calibration, spec-workflow, gh-cli alignment, rejection contract, background verification
- **v11-v20 (continuous slimming)**: commands 29→18 (-38%), AGENTS.md 290→211 (-27%), sentence-by-sentence no-op pruning, schema validation dead-key removal
- **v21-v30 (alignment + security + discipline refactor)**: integrated 6 upstream repos, gh-cli v2.97 escaping/injection security section, DCP window tuning; prune/DCP percentage-threshold tightening, grilling introduced, code-review single-pass + evidence gating, provider-layer thinking split, cache discipline, scope-first + delegate-always, atomic TODOs, 5 new skills → 24 total, README bilingual sync
- **v31 (multimodal)**: added the `deepseek-v4-flash-vision-exp` multimodal model (provider layer mirrors flash settings); added the `vision` agent and `/vision` command; orchestrator routing table gains a multimodal row; AGENTS.md model constraint updated to three models
- **v32 (session-review optimization)**: reviewed three real session logs (flash config/review + pro CAD). P0 subagent empty-result fallback (retry once → stop and tell the user, never inline heavy implementation); P1 orchestrator context hygiene (no self-exploration / no self-loading domain skills / summarize subagent results before forwarding / propagate verified facts / check coverage before re-review); P1 routing table completion (scoping→explore, commit/push→/commit); P2 opencode-config skill fixes (model allowlist references AGENTS.md, config-dir pointer, read-tool mojibake note, bundled validate-jsonc.js, classify new agents by role); P2 code-review gains full-project audit mode; P2 Git safety bans directory-level `git add`
- **v33 (quality hardening)**: fixed opencode.jsonc trailing comma; added .gitignore; enhanced research skill (18→78 lines); fixed three orchestrator routing table inconsistencies (refactor → oracle→deep-worker, simplify → oracle→light-orchestrator, deploy/release aligned with /release command); spec-workflow formatting fix; opencode-config skill now references validate-jsonc.js; simplify command template clarifies writer agent; added scripts/validate-jsonc.js with string-aware comment stripping
- **v34 (targeted slimming + high-value borrows)**: handoff gains pi's structured headings (Goal / Constraints & Preferences / Progress / Key Decisions / Next Steps / Critical Context); shared-language gains "glossary and nothing else" + ADR triage (mattpocock); gh-cli gains secondary rate-limit detection; opencode.jsonc thinking comment corrected to provider passthrough; README fixed the stale snapshot claim (command count verified correct at 19); confirmed two-axis review / delta specs / cache discipline already implemented — no new skills added
- **v35 (borrow from opencode@dev + version alignment)**: added the `/learn` command (directory-level AGENTS.md learning distillation, from opencode@dev learn.md); added the `deepseek-harness` reference mount (official model-config guidance); orchestrator gains a `permission.task` allowlist (`"*":"deny"` + 10 subagents allow, from opencode@dev's single-tool agent pattern); gh-cli skill version aligned v2.97→v2.98; opencode-config skill model constraint updated to three models (incl. vision-exp); dcp.jsonc comment fixed 128K→1M window; command count 19→20

## Repository Structure

```text
├── opencode/                     # OpenCode config directory (deployable independently)
│   ├── agents/                   # 11 specialized Agents
│   │   ├── orchestrator.md       # main entry: intent gate + model-aware routing
│   │   ├── planner.md            # flash: architecture & planning
│   │   ├── deep-worker.md        # pro: heavy implementation
│   │   ├── oracle.md             # pro: deep code analysis (read-only)
│   │   ├── reviewer.md           # pro: single-pass code review (read-only)
│   │   ├── consultant.md         # flash: solution discussion & advice
│   │   ├── ui-builder.md         # flash: frontend & UI
│   │   ├── explore.md            # flash: codebase search (read-only)
│   │   ├── librarian.md          # flash: external retrieval (read-only)
│   │   ├── light-orchestrator.md # flash: simple editing
│   │   └── vision.md             # flash-vision: multimodal understanding
│   ├── skills/                   # 24 on-demand skills
│   │   ├── code-review/          # lightweight single-pass review + evidence gating
│   │   ├── codemap/              # generates repository structure map
│   │   ├── gh-cli/               # GitHub CLI v2.98+ reference + security advisory
│   │   ├── git-master/           # advanced Git operations
│   │   ├── git-release/          # Tag releases
│   │   ├── handoff/              # compress sessions into handoff docs
│   │   ├── opencode-config/      # meta-skill: this repo's config writing
│   │   ├── reflect/              # continuous improvement
│   │   ├── remove-deadcode/      # dead code detection & removal
│   │   ├── resolving-merge-conflicts/ # per-hunk conflict resolution discipline
│   │   ├── security-review/      # security review checklist
│   │   ├── shared-language/      # domain glossary (saves tokens)
│   │   ├── simplify/             # behavior-preserving code simplification
│   │   ├── spec-workflow/        # spec-driven development
│   │   ├── tech-debt-audit/      # tech debt audit (9 dimensions, read-only report)
│   │   ├── prototype/            # throwaway prototype for design questions
│   │   ├── wayfinder/            # fog-of-war navigation for huge codebases
│   │   ├── verify-with-docs/     # retrieval-first API verification
│   │   ├── grilling/             # requirements alignment interview
│   │   ├── research/             # deep research on open topics (with citations)
│   │   ├── to-questionnaire/     # off-channel one-shot questionnaire
│   │   ├── wait-what/            # restates hard-to-parse messages in one sentence for confirmation
│   │   ├── wizard/               # human step-by-step wizard (bash -n verified)
│   │   └── writing-for-agents/   # writing for agent-facing docs
│   ├── opencode.jsonc            # main config (20 commands)
│   ├── AGENTS.md                 # global rules
│   └── dcp.jsonc                 # DCP context compression (DeepSeek V4 1M, 60%/30% percentage thresholds)
├── README.md
├── README.en-US.md
└── LICENSE
```

## Usage Guide

### Mode 1: Orchestrator Auto-Routing (Default)

Describe your needs in natural language; the Orchestrator analyzes intent and picks the most suitable agent and model to execute.

```text
"Help me debug the login API error"     → oracle analyzes root cause → returns diagnostic report
"Optimize this loop, performance is poor" → oracle analyzes → deep-worker implements optimization
"Review this PR for me"                 → reviewer performs multi-dimensional review → returns tiered report
"I want to add an export feature to the user module" → planner drafts plan → deep-worker implements
"How to use React 19's use() API"       → librarian checks docs → returns signature and examples
```

### Mode 2: Command Alias Shortcuts

| Scenario | Command |
| --- | --- |
| Complex implementation / multi-file changes | `/deep` |
| Lightweight changes / single-file edits | `/quick` |
| Technical proposal / architecture design | `/plan` |
| Bug hunting / deep analysis | `/oracle` |
| Code review | `/review` |
| External search / API lookup | `/search` |
| Frontend / UI work | `/ui` |
| Multimodal / image understanding | `/vision` |
| Approach discussion / trade-offs | `/consult` |
| Structured debugging | `/oracle` |

### Typical Workflows

**Building a new feature (spec-driven):**
```text
/spec-propose  → /spec-apply  → /review
```

**Debugging a bug:**
```text
/oracle  → /deep  → /rmslop  → /commit
```

**Code review:**
```text
/review-pr   ← review PR + auto-reply on GitHub
/review      ← lightweight single-pass review
```

## Design Philosophy

- **Pure config-driven, zero extra dependencies** — every capability comes from `opencode.jsonc` + `agents/*.md` + `skills/*/SKILL.md` + `AGENTS.md`
- **Maximum use of the DeepSeek V4 model family** — Pro for deep reasoning and heavy implementation, Flash for routing, planning, and routine execution, Flash-Vision for multimodal tasks
- **Token efficiency first** — path references instead of pasted files, skills loaded on demand, tiered compression management
- **Plugins add value without stealing the spotlight** — superpowers provides process discipline, DCP (dcp.jsonc) handles proactive dedup + compression thresholds, built-in compaction (opencode.jsonc) handles auto-trigger + prune fallback
- **Execution separated from exploration** — deep-worker/light-orchestrator must not research or delegate; explore/librarian must not modify
- **Cache + thinking discipline** — stable static prefixes to hit DeepSeek's prompt cache; flash disables thinking + temperature 0 (provider layer), pro keeps thinking on by default
- **Scope First + Delegate Always** — define scope first (2+ steps / multi-file / architecture changes go through planner), then delegate execution; top-level tokens are reserved for routing and hard problems
- **Atomic TODOs** — multi-step tasks start with an ordered TODO list, one item in_progress → completed at a time; format `path: action for scenario — verify by check`
- **Continuous improvement** — reflect mechanizes friction discovery, code-review's evidence gating guards quality
