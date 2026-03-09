# Source Install macOS Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让源码一键安装脚本支持 macOS，同时保留 Linux 现有行为，并提供统一的 `install-source.sh` 入口。

**Architecture:** 以当前 `scripts/install/install-ubuntu-source.sh` 为基础提炼出跨平台主脚本 `scripts/install/install-source.sh`，只调整平台检查与文案，不扩展安装能力。旧脚本保留为兼容包装层，避免已有入口失效；安装文档同步切换到新入口。

**Tech Stack:** POSIX shell, Cargo, repo install docs

---

### Task 1: 创建跨平台源码安装主脚本

**Files:**
- Create: `scripts/install/install-source.sh`
- Reference: `scripts/install/install-ubuntu-source.sh`

**Step 1: 以现有脚本内容为基础写出新入口**

将 `install-ubuntu-source.sh` 的主体逻辑复制到 `install-source.sh`，保留以下行为：

```sh
INSTALL_PATH="${CODEX_INSTALL_PATH:-}"
SKIP_BACKUP=0
SKIP_BUILD="${CODEX_SKIP_BUILD:-0}"
SKIP_PLATFORM_CHECK="${CODEX_SKIP_PLATFORM_CHECK:-0}"
SOURCE_BIN_OVERRIDE="${CODEX_SOURCE_BIN:-}"
```

以及：

```sh
SOURCE_BIN="$WORKSPACE_DIR/target/release/codex"
(
  cd "$WORKSPACE_DIR"
  cargo build -p codex-cli --release
)
```

**Step 2: 调整帮助文案为跨平台表述**

把 usage 从 Ubuntu/Debian 专用文案改成 macOS/Linux 通用文案，例如：

```sh
Usage: scripts/install/install-source.sh [--install-path PATH] [--skip-backup]

Build the current repository's Rust CLI, back up the existing global codex binary,
and install the freshly built binary to a global path on macOS or Linux.
```

**Step 3: 放宽平台检查并保留 Linux warning**

把平台检查改成：

```sh
case "$(uname -s)" in
  Darwin) ;;
  Linux)
    if [ -r /etc/os-release ]; then
      . /etc/os-release
      case "${ID:-}" in
        ubuntu|debian) ;;
        *)
          echo "Warning: this script was originally written for Ubuntu/Debian-style Linux, detected ${ID:-unknown}." >&2
          ;;
      esac
    fi
    ;;
  *)
    echo "This installer supports macOS and Linux." >&2
    exit 1
    ;;
esac
```

保留 `CODEX_SKIP_PLATFORM_CHECK=1` 的短路行为。

**Step 4: 运行帮助命令验证新脚本可执行**

Run: `./scripts/install/install-source.sh --help`
Expected: 退出码为 0，输出包含 `macOS or Linux`

**Step 5: Commit**

```bash
git add scripts/install/install-source.sh
git commit -m "feat: add cross-platform source install script"
```

### Task 2: 将旧 Ubuntu 脚本改为兼容包装层

**Files:**
- Modify: `scripts/install/install-ubuntu-source.sh`
- Reference: `scripts/install/install-source.sh`

**Step 1: 将旧脚本改成薄包装**

把旧脚本改为只负责兼容入口，不再保留完整安装实现。示例结构：

```sh
#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

echo "scripts/install/install-ubuntu-source.sh is deprecated; use scripts/install/install-source.sh" >&2
exec "$SCRIPT_DIR/install-source.sh" "$@"
```

**Step 2: 确认包装层保持参数透传**

Run: `./scripts/install/install-ubuntu-source.sh --help`
Expected:
- 先输出 deprecation 提示
- 后续显示 `install-source.sh` 的帮助内容
- 退出码为 0

**Step 3: Commit**

```bash
git add scripts/install/install-ubuntu-source.sh
git commit -m "chore: keep ubuntu source installer as wrapper"
```

### Task 3: 更新安装文档并做无副作用验证

**Files:**
- Modify: `docs/install.md`

**Step 1: 更新安装说明标题和示例命令**

把文档中的：

```md
### Ubuntu source install with backup
```

改成：

```md
### macOS/Linux source install with backup
```

并把示例命令更新为：

```bash
./scripts/install/install-source.sh
```

同时补一句旧脚本仍可作为兼容入口使用。

**Step 2: 做一次无副作用安装验证**

先准备一个本地临时可执行文件作为 `CODEX_SOURCE_BIN`：

```bash
tmpdir="$(mktemp -d)"
printf '#!/bin/sh\nexit 0\n' > "$tmpdir/codex"
chmod 755 "$tmpdir/codex"
```

然后执行：

```bash
CODEX_SKIP_BUILD=1 CODEX_SOURCE_BIN="$tmpdir/codex" ./scripts/install/install-source.sh --install-path "$tmpdir/bin/codex"
```

Expected:
- 不触发真实构建
- 在临时目录生成 `bin/codex`
- 输出 `Installed successfully`

如需兼容入口也一起验证，再执行：

```bash
CODEX_SKIP_BUILD=1 CODEX_SOURCE_BIN="$tmpdir/codex" ./scripts/install/install-ubuntu-source.sh --install-path "$tmpdir/bin-compat/codex"
```

Expected:
- 先打印兼容提示
- 最终安装成功

**Step 3: 检查变更**

Run: `git diff -- scripts/install/install-source.sh scripts/install/install-ubuntu-source.sh docs/install.md`
Expected: 只包含主脚本、兼容包装层和安装文档的预期改动

**Step 4: Commit**

```bash
git add docs/install.md
git commit -m "docs: update source install instructions"
```
