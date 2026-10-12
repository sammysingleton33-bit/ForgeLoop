# AI providers: Codex, AreaAI, Claude Code

Research for FL-0004, done 2026-10-12. Every fact has an ID so a verifier can check it and record corrections.

**Legend.** Conf = high / med / low. Type: **O** = observed (the source says it), **I** = inferred (our analysis).

**Access limits during this research (O).** The session proxy blocked these hosts (403 or DNS failure): `developers.openai.com`, `help.openai.com`, `learn.chatgpt.com`, `areaai.com`, `www.areaai.com`, and most third-party blogs. That means:
- **OpenAI facts** come from two places. One is the open-source `openai/codex` repository, read from `raw.githubusercontent.com` on its `main` branch on 2026-10-12. The other is WebSearch snippets of OpenAI pages. Snippet-only facts are capped at **med**.
- **Anthropic facts** come from pages fetched directly: `code.claude.com/docs`, `claude.com/pricing` and `support.claude.com`.

---

## 0. Bottom line

| # | Recommendation | Type |
|---|---|---|
| R1 | **Codex (Plus).** Run Codex CLI from `forgeloop/`. Use `codex -C forgeloop`, or `cd forgeloop && codex`, so both AGENTS.md files load and `forgeloop/AGENTS.md` takes precedence. For cloud tasks, choose branch `forge/integration` in the task UI, or run `codex cloud exec --env <ENV_ID> --branch forge/integration "<prompt>"`. Always paste the `forge.py prompt` output, which embeds `forgeloop/AGENTS.md`, because Codex cloud's starting directory is not documented. | I |
| R2 | **AreaAI is not verified.** We could not confirm that areaai.com is an AI model or API provider. Use **manual copy-paste only**, with `python tools/forge.py prompt <ID> --out prompt.md`. Have a Claude worker commit the output after review. Do not build an automated integration. | I |
| R3 | **Claude Max, 5 workers.** Five cloud sessions (one VM and one branch each) are supported, but they all draw on **one** plan usage pool. Expect limits to be reached about 5× faster than with one session. Watch `/usage` and stagger heavy tasks. | I (from C-U1…U5) |
| R4 | **Instruction-loading gap (repo fix, owner FORGE-00).** `forgeloop/CLAUDE.md` tells Claude *in words* to read AGENTS.md. By default Claude Code then reads CLAUDE.md files only (C-M1, C-M2). Add a line `@AGENTS.md` to `forgeloop/CLAUDE.md` so the rules are imported automatically. | I |
| R5 | **Protect `forge/integration` and `main` with a GitHub ruleset.** The Claude cloud git proxy does not restrict which branches a session can push to (C-C9). Today only instructions prevent a worker from pushing to integration. | I |

---

## 1. OpenAI Codex on ChatGPT Plus ($20/mo)

### 1.1 Surfaces available to a Plus user

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| X-S1 | Codex CLI runs locally. To use it on a plan you run `codex` and choose **Sign in with ChatGPT**. Plus, Pro, Business, Edu and Enterprise are listed. An API key is an alternative. | raw.githubusercontent.com/openai/codex/main/README.md | fetched 2026-10-12 | high | O |
| X-S2 | Install with `npm install -g @openai/codex`, `brew install --cask codex`, or `curl -fsSL https://chatgpt.com/codex/install.sh \| sh`. `codex app` opens the desktop app. The cloud agent ("Codex Web") lives at chatgpt.com/codex. | same README | fetched 2026-10-12 | high | O |
| X-S3 | The IDE extension works in VS Code and in forks such as Cursor and Windsurf. You sign in with ChatGPT or an API key. You can delegate a task to the cloud by choosing an environment and **Run in the cloud**. | developers.openai.com/codex/ide (search snippet) | not shown | med | O |
| X-S4 | JetBrains support (IntelliJ, PyCharm, WebStorm, Rider) arrived in January 2026 through the AI Assistant plugin, version 2025.3 or later. | neowin.net/news/openais-codex-extension-is-now-available-for-jetbrains-ides | 2026-01 | med | O |
| X-S5 | Plus includes Codex on the web, CLI, IDE extension and iOS, plus cloud integrations such as automatic code review and Slack. The API-key option has no cloud features. | developers.openai.com/codex/pricing; /codex/codex-manual.md (search snippets) | not shown | med | O |
| X-S6 | Cloud setup: connect GitHub, choose which repositories Codex can access, then create an environment per repository (dependencies, environment variables, secrets). Codex creates a container, checks out the repo **at the selected branch or commit SHA**, then runs the setup script. Internet is on during setup and **off by default during the agent phase**. | developers.openai.com/codex/cloud and /codex/cloud/environments (search snippets) | not shown | med | O |
| X-S7 | The CLI has an experimental `codex cloud` subcommand (alias `cloud-tasks`) with `exec`, `status`, `list`, `apply` and `diff`. `exec` takes `--env ENV_ID` (required), `--branch BRANCH` ("defaults to current branch") and `--attempts 1-4` (best-of-N). `apply <TASK_ID>` applies a cloud diff locally. | codex-rs/cloud-tasks/src/cli.rs and codex-rs/cli/src/main.rs (source) | main, 2026-10-12 | high | O |
| X-S8 | CLI flags: `--cd` / `-C DIR` ("use the specified directory as its working root"), `--add-dir DIR` (extra writable directories), and `--worktree` ("Run the session in a new managed Git worktree"). | codex-rs/utils/cli/src/shared_options.rs (source) | main, 2026-10-12 | high (flags exist on main; which release first shipped them: not found) | O |
| X-S9 | `@codex review` in a PR comment starts a review that flags only P0/P1 issues. Any other `@codex …` comment starts a **cloud task** with the PR as context. A follow-up such as `@codex fix it` "will fix the issue and update the pull request". Requires Codex cloud set up for the repo and Code review enabled. | developers.openai.com/codex/integrations/github (search snippet) | not shown | med | O |

### 1.2 How Codex reads AGENTS.md

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| X-A1 | **Project root** is the nearest ancestor of the working directory that contains a `project_root_markers` entry (default `.git`). Codex collects instruction files **from the project root down to the working directory, inclusive**, and does not walk above the root. | codex-rs/core/src/agents_md.rs (header comment and `agents_md_paths`) | main, 2026-10-12 | high | O |
| X-A2 | It takes **at most one file per directory**, the first match in this order: `AGENTS.override.md`, then `AGENTS.md`, then any names in `project_doc_fallback_filenames`. Empty files are skipped. | agents_md.rs (`candidate_filenames`) | main, 2026-10-12 | high | O |
| X-A3 | Files are concatenated **root first, deepest last**. There is a **combined** byte budget, `project_doc_max_bytes`, default **32 KiB**. When it runs out, later (deeper) files are truncated or dropped. | agents_md.rs (`read_agents_md`); core/src/config/mod.rs (`AGENTS_MD_MAX_BYTES … // 32 KiB`) | main, 2026-10-12 | high | O |
| X-A4 | Global instructions from `~/.codex` are combined with the project docs, separated by `--- project-doc ---`. At the global level only the first non-empty file is used. | agents_md.rs (separator); developers.openai.com/codex/guides/agents-md (snippet, for "first non-empty") | 2026-10-12 | med | O |
| X-A5 | Precedence rules in Codex's default base instructions: an AGENTS.md applies to the whole directory tree it sits in. **More deeply nested files win on conflict.** Direct system, developer and user prompt instructions beat AGENTS.md. Files from the repo root down to the working directory are injected automatically. When working in a subdirectory *below* the working directory, the model is told to "check for any AGENTS.md files that may be applicable". | codex-rs/protocol/src/prompts/base_instructions/default.md | main, 2026-10-12 | high (text exists); med (that every model or surface uses this base prompt) | O |
| X-A6 | The instruction chain is built once when a run starts. In the TUI that usually means once per session. | developers.openai.com/codex/guides/agents-md (search snippet) | not shown | med | O |
| X-A7 | Code review applies guidance from the **closest AGENTS.md to each changed file**. Put review rules under a "Review guidelines" heading. | developers.openai.com/codex/integrations/github (search snippet) | not shown | med | O |
| X-A8 | **Not found:** the starting working directory of a Codex **cloud** task. It is presumably the repo root, but that is unverified. If it is the root, only `DLS/AGENTS.md` is injected automatically, and `forgeloop/AGENTS.md` depends on the model following X-A5. | — | — | — | I |

### 1.3 Branch and PR behaviour

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| X-B1 | In the web flow you review the diff, ask for follow-ups, then **open a pull request** from the task. | developers.openai.com/codex/cloud (search snippet) | not shown | med | O |
| X-B2 | The cloud task checks out the **selected branch or commit SHA** (see X-S6). From the CLI, `codex cloud exec --branch <name>` selects it (see X-S7). | as cited | 2026-10-12 | high (CLI); med (web) | O |
| X-B3 | Community reports: new tasks start on the default branch, the branch selection resets to `main` on page refresh, and there are feature requests to keep the selected branch. | community.openai.com/t/…/1286601 and /1279595 | 2025 (forum) | low | O |
| X-B4 | Early on, follow-ups opened new PRs instead of updating the existing one. A later forum reply says a feature to update PRs shipped, but that it was "solved on web" and not in the ChatGPT app. | community.openai.com/t/prs-opened-by-codex-are-not-updated-with-latest-changes/1266174 | 2025 (forum) | low | O |
| X-B5 | **Not found:** the branch name Codex web gives to PR branches, and how it chooses the PR base branch. Our convention `codex/<task-id>-<slug>` therefore may not be honoured by the Create PR button. | — | — | — | I |

### 1.4 Usage limits for Plus

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| X-L1 | Plus has a **rolling 5-hour limit and a weekly limit** on Codex and ChatGPT Work. The 5-hour limit was reinstated on **2026-08-25** after a pause that began in mid-July. It was announced on X by Thibault Sottiaux on 2026-08-24. Pro $100 and $200 plans are exempt from the 5-hour limit "for the upcoming months". | 9to5mac.com/2026/08/24/openai-restores-5-hour-codex-and-work-limits-for-chatgpt-plus-users/; techrepublic.com/article/news-openai-five-hour-codex-limit-chatgpt-plus/; notebookcheck.net | 2026-08-24/25 | med (several outlets agree; no official page read) | O |
| X-L2 | When either limit is reached: wait for the reset, or buy additional credits. | same news coverage | 2026-08 | med | O |
| X-L3 | **Exact Plus numbers: not verified.** Secondary sources quote per-model "local messages per 5 hours" ranges from OpenAI's pricing page, but they disagree on both model names and numbers across 2026 articles. Read the current figures at developers.openai.com/codex/pricing or in Codex's usage view. Do not plan on any specific number. | eesel.ai/blog/codex-pricing; morphllm.com/codex-pricing; munderdiffl.in/blog/codex-pricing | 2026 (various) | low | O |
| X-L4 | Cloud tasks reportedly draw from the **same** 5-hour and weekly pool as local use, and cost more per task than local work. | sinatra.dev/blog/openai-codex-cloud-pricing-explained; justinmckelvey.com/blog/codex-usage-limits (snippets) | 2026 | low | O |
| X-L5 | Plus capacity is small and shared. Spend it on reviews, specs and research (as `agents/codex/LAUNCH.md` already plans), not on bulk code generation. Prefer local CLI over cloud for long iterations (because of X-L4). | — | — | — | I |

### 1.5 How-to for this repo

| Need | Do this | Basis |
|---|---|---|
| Work only in `forgeloop/` (CLI) | `cd DLS/forgeloop && codex`, or `codex -C forgeloop`. Both `DLS/AGENTS.md` and `forgeloop/AGENTS.md` load, and forgeloop wins on conflict. Add `--add-dir` only if another path must be writable. | X-A1, X-A3, X-A5, X-S8 (I) |
| Work only in `forgeloop/` (cloud or `@codex`) | Put "Read `forgeloop/AGENTS.md` first; edit only under `forgeloop/`" at the top of the prompt. `forge.py prompt` already embeds forgeloop/AGENTS.md. | X-A5, X-A8 (I) |
| Start from a non-default branch | Web: pick `forge/integration` in the task's branch control, and re-check after a page refresh (X-B3). CLI: `codex cloud exec --env <ENV_ID> --branch forge/integration "…"`. | X-S6, X-S7, X-B3 |
| Control the PR branch name and base | Most reliable: `codex cloud apply <TASK_ID>` (or local CLI work), then create `codex/<task-id>-<slug>` yourself, push, and open the PR into `forge/integration`. If the web Create PR button is used, retarget the base to `forge/integration` on GitHub. | X-S7, X-B5 (I) |
| Instruction budget | Current combined size: `DLS/AGENTS.md` 3,281 B + `forgeloop/AGENTS.md` 3,459 B = 6.7 KiB, well under 32 KiB. Keep the root file small, because it consumes the budget first. | X-A3 (measured 2026-10-12, O) |
| Toolchain in cloud | Install the Roblox toolchain (Rokit, Lune, Selene, StyLua, Rojo) in the environment **setup script**, because agent-phase internet is off by default. | X-S6 (I) |

---

## 2. "AreaAI" (areaai.com)

**Verdict: NOT VERIFIED. We could not confirm that "AreaAI" at areaai.com is an AI model or API provider.** We found no models, API, OpenAI compatibility, pricing, limits or privacy terms. Every one of those fields is **not found**.

| ID | Finding | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| A-1 | `areaai.com` and `www.areaai.com` could not be fetched from this session (proxy 403 / DNS failure). That says **nothing** about whether the site exists, only that we could not see it. | curl and WebFetch attempts in this session | 2026-10-12 | high | O |
| A-2 | Six web searches ("AreaAI", "areaai.com", "Area AI" with API, models, pricing, login, OpenAI-compatible) returned **no page from areaai.com** and no documentation of an AreaAI model or API. | WebSearch | 2026-10-12 | med (search coverage is not exhaustive) | O |
| A-3 | Similar names that are **different things**: "AreAI: AI Home Living Decor" (an Android interior-design app, `com.leapailabs…`); "Area AI", Tajikistan's AI free zone (the-area.ai); "AREA AI", real-estate ad tools (areahub.ai); the `Area.ai` domain, listed for sale on atom.com; Area-I, Inc., an aerospace company at areai.com. | play.google.com (AreAI); the-area.ai; areahub.ai; atom.com/name/Area.ai; discovery.patsnap.com/company/area-i/ | 2026-10-12 (search) | med | O |
| A-4 | Models offered, API, OpenAI compatibility, pricing, rate limits, data retention and training use: **not found**. | — | — | — | — |

**Recommendation (I).**
1. **Use a manual handoff only:**
   - Run `python tools/forge.py prompt <ID> --out /tmp/<ID>-prompt.md`.
   - Paste the file into the fallback chat.
   - Paste the reply back into `production/handoffs/<date>-<ID>-areaai.md`.
   - Have a Claude worker review it, validate it and commit it, marking it **unverified, external model**.
   - The prompt is up to about 60 KB (`MAX_CONTEXT_BYTES = 60_000` in `tools/forge.py`), so check that the target chat accepts that much text.
2. **Do not automate** until the owner provides, from the vendor's own site:
   - (a) API docs with base URL, auth and model list;
   - (b) a statement on OpenAI-compatible `/v1/chat/completions`;
   - (c) pricing and limits;
   - (d) privacy/ToS terms covering retention and training on inputs.

   Then run one test call with a throwaway key stored outside Git. If (b) holds, a thin `forge.py` sender could reuse the same compiled prompt. That needs an approval gate (spending money, external service).
3. **Never paste secrets into an unverified service.** Prompts include repo files: check that a compiled prompt contains no keys, cookies or personal data before pasting it anywhere.
4. Ask the owner which product they mean, and where they saw it (URL, app store link or invoice). A typo for another service cannot be ruled out, and we are **not** guessing which one.

---

## 3. Claude Code: 5 parallel workers on one repo with a Max plan

### 3.1 Cloud vs local sessions

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| C-C1 | Cloud sessions are available on Pro, Max, Team and eligible Enterprise seats. They run on Anthropic-managed VMs and keep running after you close the laptop. You can start them from claude.ai/code, the Claude app Code tab, the Desktop app (**Cloud**), `claude --cloud "<task>"`, or Routines. | code.claude.com/docs/en/claude-code-on-the-web | fetched 2026-10-12 | high | O |
| C-C2 | Each cloud session runs in its own isolated VM (Ubuntu 24.04, x86_64) on a fresh clone. "Each task gets its own session and its own branch." Claude pushes the branch, and you review the diff and create the PR in the same conversation. | /docs/en/web-quickstart; /docs/en/cloud-environments | fetched 2026-10-12 | high | O |
| C-C3 | Choosing a base branch: the repository selector "shows a branch selector. Change it to start Claude from a feature branch instead of the default." `claude --cloud` clones the GitHub remote **at your current branch**, not your local checkout, so push first. | /docs/en/web-quickstart; /docs/en/claude-code-on-the-web | fetched 2026-10-12 | high | O |
| C-C4 | Cloud sessions get only what is **committed**: the repo's CLAUDE.md, `.claude/settings.json` hooks and permissions, `.claude/rules/`, `.claude/skills/` and `.claude/agents/`. They do **not** get your `~/.claude/CLAUDE.md`, user skills, or user-enabled plugins. | /docs/en/cloud-environments ("What carries over") | fetched 2026-10-12 | high | O |
| C-C5 | You can run several `claude --cloud "…"` commands. Each "creates its own cloud session that runs independently". | /docs/en/claude-code-on-the-web | fetched 2026-10-12 | high | O |
| C-C6 | `claude --teleport <session-id>` pulls a cloud session and its branch into a local terminal (needs a clean git state and the same account). `claude -p "msg" --cloud <session-id>` queues a follow-up into a running cloud session. Pushing a local session to the cloud is not possible from the CLI, though the Desktop app can do it. | /docs/en/claude-code-on-the-web | fetched 2026-10-12 | high | O |
| C-C7 | Command and setup time limits: Bash foreground commands default to 2 minutes (up to 10 on request), and commands moved to the background can run up to 30 more minutes. SessionStart hooks are cancelled after 600 s unless a `timeout` is set. Setup scripts are cached only if they finish in about 5 minutes. Idle sessions expire: the conversation is restored, but running background work is lost. | /docs/en/cloud-environments; /docs/en/claude-code-on-the-web | fetched 2026-10-12 | high | O |
| C-C8 | **Projects** (public beta on Pro and Max, rolling out gradually): one coordinating conversation starts parallel cloud "threads". Each thread has its own branch and PR. Enforced limit: 200 new threads per day. A thread that reaches the plan limit waits and resumes on reset. Threads require the Claude GitHub App. | /docs/en/claude-projects | fetched 2026-10-12 | high | O |
| C-C9 | Git proxy in Anthropic-hosted sessions: it "rejects branch deletions and pushes of anything other than a branch… It **doesn't limit which branches a push can update**. To do that, use branch protection rules or rulesets." The GitHub GraphQL API is blocked, so `gh pr` and `gh issue` fail; use REST (`gh api repos/…`) or the built-in GitHub tools. | /docs/en/cloud-environments ("GitHub proxy") | fetched 2026-10-12 | high | O |
| C-C10 | The cloud session branch in this environment is named `claude/<random>` (this session: `claude/zealous-dirac-0yiy1m`). | `git branch --show-current` in this session | 2026-10-12 | med (one sample) | O |
| C-C11 | Local sessions (CLI, Desktop **Local**, IDE) run on your machine. Remote Control lets you steer them from a phone or the browser. Desktop shows parallel sessions in its sidebar and can ask Claude to check on or message other **desktop-run** sessions, but not cloud or CLI sessions. | /docs/en/desktop; /docs/en/remote-control (index) | fetched 2026-10-12 | high | O |

### 3.2 Git worktrees (local parallelism)

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| C-W1 | `claude --worktree <name>` (or `-w`) creates `.claude/worktrees/<name>/` on a new branch `worktree-<name>`. Each terminal gets an isolated copy. Interactive use needs workspace trust in the directory first. | /docs/en/worktrees | fetched 2026-10-12 | high | O |
| C-W2 | When you exit: a clean, unnamed worktree is removed automatically. A worktree with changes or commits prompts you to keep or remove it. `-p` runs do not clean up. Add `.claude/worktrees/` to `.gitignore`. `.worktreeinclude` copies gitignored files such as `.env` into new worktrees. | /docs/en/worktrees | fetched 2026-10-12 | high | O |
| C-W3 | Desktop: a **worktree** option next to the branch name when starting a session, plus a **Branch prefix** setting and a Worktree location setting. Archiving the session removes its worktree. | /docs/en/desktop ("Work in parallel with sessions") | fetched 2026-10-12 | high | O |
| C-W4 | Auto memory is machine-local and shared by all worktrees of the same repository. It is not shared with cloud sessions. | /docs/en/memory | fetched 2026-10-12 | high | O |
| C-W5 | `claude --worktree` names branches `worktree-<name>`, which does not match our `forge/0N-<area>`. Keep the manual `git worktree add … -b forge/0N-<area>` from `docs/workflows/git-and-integration.md`, or use Desktop's Branch prefix setting. | — | — | — | I |

### 3.3 Naming and renaming sessions

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| C-N1 | Ways to name a session: `claude -n <name>` at startup; `/rename <name>` during a session; Ctrl+R in the session picker; from the Desktop app; from claude.ai or the app for Remote Control sessions (synced to the CLI, v2.1.221+). `claude --resume <name>` resumes by name. | /docs/en/sessions ("Name your sessions") | fetched 2026-10-12 | high | O |
| C-N2 | In cloud sessions, `/rename` takes the value as an argument (`/rename forge-01-gameplay`). This needs Claude Code v2.1.205+ in the session's environment. | /docs/en/claude-code-on-the-web ("Manage context") | fetched 2026-10-12 | high | O |
| C-N3 | Renaming from the claude.ai/code sidebar UI: **not found** in the pages read. | — | — | — | — |
| C-N4 | Name each worker session with its FORGE id (`forge-01-gameplay` … `forge-05-integration`) so the sidebar, picker and `STATUS.md` all match. | — | — | — | I |

### 3.4 Usage limits with parallel sessions (Max)

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| C-U1 | Max comes as **Max 5x** and **Max 20x**: "5x or 20x more usage than Pro", measured per 5-hour session. The pricing page shows "From $100"; its API-credit row gives $100/mo for 5x and $200/mo for 20x. Claude Code is included. | claude.com/pricing | fetched 2026-10-12 | high | O |
| C-U2 | Pro and Max have a **five-hour session limit and a weekly limit**, and Max also has "a separate weekly limit for Fable". These limits are **shared across Claude and Claude Code**. | support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan | "Updated this week" (as of 2026-10-12) | high (Fable line: med, read through a summarising fetch) | O |
| C-U3 | Cloud sessions "share rate limits with all other Claude and Claude Code usage within your account. **Running multiple tasks in parallel consumes more rate limits proportionately.**" | /docs/en/claude-code-on-the-web ("Limitations") | fetched 2026-10-12 | high | O |
| C-U4 | Published message or prompt counts per 5 hours for Max 5x or 20x: **not found** on official pages. Check live usage with `/usage` in Claude Code, or Settings > Usage on claude.ai. | support article; /docs/en/costs | fetched 2026-10-12 | high (absence on the pages read) | O |
| C-U5 | "You've hit your session limit" and "weekly limit" apply across all models, so switching model does not help. An Opus- or Sonnet-specific limit message can be bypassed with `/model`. Usage credits (`/usage-credits`) let you continue at API rates. The cache lifetime is 1 hour on a subscription, and 5 minutes once you draw on usage credits. | /docs/en/costs | fetched 2026-10-12 | high | O |
| C-U6 | With 5 workers active, the shared 5-hour window fills about 5× faster than with one. Plan: (a) give each worker one bounded task per session; (b) use Sonnet for routine implementation; (c) idle workers do not consume usage, but an auto-fix PR watch wakes them; (d) if a limit hits mid-task, the state is in Git, so the next session resumes from the task file. | from C-U3, C-C8, C-U5 | — | — | I |

### 3.5 Instruction files: CLAUDE.md vs AGENTS.md (affects this repo)

| ID | Fact | Source | Date | Conf | Type |
|---|---|---|---|---|---|
| C-M1 | By default (`claude-md-or-agents-md`), Claude reads AGENTS.md **only if there is no CLAUDE.md or CLAUDE.local.md in the working directory or above it**. Otherwise it reads CLAUDE.md files only. Direct AGENTS.md reading needs v2.1.277+. `AGENTS.override.md` is not read. | /docs/en/memory ("AGENTS.md") | fetched 2026-10-12 | high | O |
| C-M2 | "A `CLAUDE.md` that tells Claude in words to read `AGENTS.md`: Claude sees `AGENTS.md` only if it decides to open the file." The fix is an `@AGENTS.md` import line. | /docs/en/memory ("Remove an earlier AGENTS.md workaround") | fetched 2026-10-12 | high | O |
| C-M3 | CLAUDE.md files above the working directory load at launch. CLAUDE.md files in subdirectories load on demand when Claude reads, writes or edits a file there. The project-root CLAUDE.md is re-injected after `/compact`; nested ones reload on demand. | /docs/en/memory | fetched 2026-10-12 | high | O |
| C-M4 | This repo has `DLS/CLAUDE.md` and `forgeloop/CLAUDE.md`, and both say "read AGENTS.md" in words. So by default **neither AGENTS.md is auto-loaded for Claude workers**. Fix: add `@AGENTS.md` to `forgeloop/CLAUDE.md` (R4). | C-M1, C-M2, plus repo check 2026-10-12 | — | — | I |

---

## 4. Provider-neutral: what must live in Git

Principle: any model (Claude, Codex, AreaAI or other) must be able to pick up a task **from a fresh clone plus one pasted prompt**. Facts that support this: Claude cloud sessions see only committed files (C-C4); Codex cloud sees only its checkout and setup script (X-S6); chats share no memory.

| Must be in Git | Path (current) | Why | Status 2026-10-12 |
|---|---|---|---|
| Canonical rules, kept short | `forgeloop/AGENTS.md` | Codex auto-loads it (X-A1). Keep combined AGENTS.md size under 32 KiB, because the root file is counted first (X-A3). | exists |
| Claude shim that **imports** rules | `forgeloop/CLAUDE.md` containing `@AGENTS.md` | Claude ignores AGENTS.md when a CLAUDE.md exists (C-M1, C-M2). | exists, no import (R4) |
| Root routing line | `DLS/AGENTS.md`: "Work under `forgeloop/` follows `forgeloop/AGENTS.md`" | Codex cloud may start at the repo root (X-A8). Needs owner approval because it is a DLS file. | missing |
| Task queue with status, owner, dependencies, evidence and log | `production/tasks/FL-*.md` | Single source of work; compiled by `forge.py prompt`. | exists |
| Role and state per worker | `agents/<id>/MISSION.md`, `STATUS.md` (branch, PR, task, blockers) | Lets a new session or another model resume a role. | exists (forge-00…05, codex) |
| Decisions and project state | `DECISIONS.md`, `PROJECT_STATUS.md`, `ROADMAP.md` | Avoids re-deciding; any model can see current truth. | exists |
| Handoffs and requests between workers or models | `production/handoffs/` (TEMPLATE) | Cross-provider communication is files plus commits only. | exists |
| Ownership map and git workflow | `docs/workflows/team.md`, `git-and-integration.md` | Says who edits what, which branch, and which PR base. | exists |
| Contracts | `roblox/src/shared/Contracts/`, `docs/architecture/interfaces.md` | Lets parallel workers integrate without chat. | interfaces.md exists |
| Runnable checks | `roblox/scripts/check.sh`, `blender/scripts/check.sh`, `tools/forge.py validate`, CI workflow | "Done" means the same thing for every provider. | partly (per other tasks) |
| Environment recipe | a setup script plus a doc mirroring the Claude cloud environment and the Codex environment settings | Vendor environment config lives in vendor UIs, not in Git, so Git must hold the recipe (C-C4, X-S6). | not found in repo (I) |
| Prompt templates and compiled prompt tool | `prompts/templates/`, `tools/forge.py prompt <ID>` | Gives an identical work order to any model, including manual paste (R2). | tool exists |
| Evidence and research with source, date, confidence | `docs/research/` | Workers rely on verified facts, not on model memory. | this file |
| **Never in Git** | secrets, `.ROBLOSECURITY`, Open Cloud and API keys, personal data | Use vendor environment secrets. Anthropic-hosted environments on Pro and Max keep network secrets outside the sandbox (/docs/en/claude-code-on-the-web, "Security and isolation", O, high). | rule in AGENTS.md |
| **Outside Git but required** | a GitHub ruleset on `forge/integration` and `main` | The proxy does not restrict push targets (C-C9) (R5). | not verified (needs repo admin) |

---

## 5. Open items for the verifier or owner
1. **Codex:**
   - Read developers.openai.com/codex/pricing from a non-proxied browser and record the Plus limits with the date (X-L3).
   - Confirm the starting working directory for Codex cloud tasks (X-A8).
   - Confirm the PR branch naming and base selection (X-B5).
2. **AreaAI:** the owner should supply the exact URL or app and what it was used for. Until then the status stays NOT VERIFIED (section 2).
3. **Claude:**
   - Confirm sidebar rename on claude.ai/code (C-N3).
   - Confirm whether `forge/integration` has branch protection (R5).

## Sources (fetched or searched 2026-10-12)
- Codex source: https://raw.githubusercontent.com/openai/codex/main/README.md · …/codex-rs/core/src/agents_md.rs · …/codex-rs/core/src/config/mod.rs · …/codex-rs/protocol/src/prompts/base_instructions/default.md · …/codex-rs/cloud-tasks/src/cli.rs · …/codex-rs/utils/cli/src/shared_options.rs · …/codex-rs/cli/src/main.rs
- OpenAI docs (search snippets only): https://developers.openai.com/codex/guides/agents-md · https://developers.openai.com/codex/cloud · https://developers.openai.com/codex/cloud/environments · https://developers.openai.com/codex/ide · https://developers.openai.com/codex/integrations/github · https://developers.openai.com/codex/pricing
- News and forums: https://9to5mac.com/2026/08/24/openai-restores-5-hour-codex-and-work-limits-for-chatgpt-plus-users/ · https://www.techrepublic.com/article/news-openai-five-hour-codex-limit-chatgpt-plus/ · https://www.notebookcheck.net/OpenAI-abruptly-restores-harsh-5-hour-Codex-and-Work-limits-for-ChatGPT-Plus.1378377.0.html · https://www.neowin.net/news/openais-codex-extension-is-now-available-for-jetbrains-ides/ · https://community.openai.com/t/prs-opened-by-codex-are-not-updated-with-latest-changes/1266174 · https://community.openai.com/t/feature-request-maintain-branch-selection-for-new-tasks-in-codex-across-sessions/1286601 · https://community.openai.com/t/preserve-current-branch-with-codex-remote-agent/1279595 · https://www.eesel.ai/blog/codex-pricing · https://www.morphllm.com/codex-pricing · https://munderdiffl.in/blog/codex-pricing/ · https://www.sinatra.dev/blog/openai-codex-cloud-pricing-explained · https://justinmckelvey.com/blog/codex-usage-limits
- AreaAI searches: https://play.google.com/store/apps/details?id=com.leapailabs.interior.design.home.renovation.app · https://the-area.ai/ · https://www.areahub.ai/ · https://www.atom.com/name/Area.ai · https://discovery.patsnap.com/company/area-i/
- Anthropic: https://code.claude.com/docs/en/claude-code-on-the-web · https://code.claude.com/docs/en/web-quickstart · https://code.claude.com/docs/en/cloud-environments · https://code.claude.com/docs/en/worktrees · https://code.claude.com/docs/en/sessions · https://code.claude.com/docs/en/desktop · https://code.claude.com/docs/en/memory · https://code.claude.com/docs/en/costs · https://code.claude.com/docs/en/agents · https://code.claude.com/docs/en/claude-projects · https://claude.com/pricing · https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan
