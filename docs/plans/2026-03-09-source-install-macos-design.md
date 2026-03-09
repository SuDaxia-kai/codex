# Source Install macOS Support Design

**背景**

仓库当前已有两个安装入口：

- `scripts/install/install.sh`：面向发布产物的跨平台安装器，支持 macOS 和 Linux。
- `scripts/install/install-ubuntu-source.sh`：面向当前 checkout 的源码安装器，负责构建 `codex-cli`、备份现有 `codex`，并安装到全局路径。

现有缺口不是“macOS 无法安装 Codex”，而是“没有一个一键脚本把当前本地代码构建后安装到 macOS 上的全局 `codex` 路径”。

**目标**

提供一个支持 macOS 和 Linux 的源码安装脚本，用当前仓库代码构建 `codex-cli` 并安装到目标路径，同时保留现有的备份、权限提升和路径解析行为。

**非目标**

- 不改动发布版安装流程
- 不自动安装 Homebrew、Rust、Xcode CLT 或其他系统依赖
- 不引入新的 PATH 修改逻辑
- 不顺带安装 `rg`
- 不为 macOS 设计独立默认安装目录

## 方案选项

### 方案 A：新增 `install-macos-source.sh`

为 macOS 单独新增一份脚本，复制 Ubuntu 脚本的大部分逻辑，仅修改平台检查和提示文案。

优点：

- 用户入口直观
- 改动局部，看起来简单

缺点：

- 逻辑重复
- 后续安装行为变更需要双份维护
- Linux 和 macOS 行为容易逐渐漂移

### 方案 B：将现有脚本泛化为 `install-source.sh`

把 `install-ubuntu-source.sh` 升级为 macOS/Linux 通用源码安装脚本，并保留旧脚本作为兼容包装层。

优点：

- 单一实现，维护成本低
- 用户心智更清晰，源码安装统一入口
- 可以保留现有 Linux 使用方式，减少迁移成本

缺点：

- 需要调整脚本命名和文档
- 需要处理兼容入口

### 方案 C：不加脚本，只靠手动命令

文档中说明用户自行 `cargo build -p codex-cli --release` 后手动拷贝到目标路径。

优点：

- 实现成本最低

缺点：

- 不满足“一键安装”的需求
- 用户需要自行处理备份、目标路径和 `sudo`

## 结论

采用方案 B。

这是最小且可持续的改法：保留已有源码安装逻辑，只把平台限制从 Ubuntu/Debian 扩展到 macOS/Linux，并提供统一入口。

## 设计细节

### 脚本结构

- 新增主入口：`scripts/install/install-source.sh`
- 保留 `scripts/install/install-ubuntu-source.sh` 作为兼容包装层
- 包装层负责提示入口已迁移，并转调 `install-source.sh`

### 平台行为

- `Darwin`：直接允许执行源码安装流程
- `Linux`：允许执行，并继续保留对 `/etc/os-release` 的检查和非 `ubuntu/debian` 的 warning
- 其他平台：报错退出，并提示该脚本仅支持 macOS 和 Linux

### 保持不变的行为

- 默认安装路径解析逻辑：
  - 优先覆盖当前 `codex` 的解析路径
  - 如果不存在，则安装到 `/usr/local/bin/codex`
- 备份逻辑：
  - 默认对现有目标文件做时间戳备份
  - `--skip-backup` 仍然可用
- 权限逻辑：
  - 目标路径无写权限时自动使用 `sudo`
- 构建逻辑：
  - 默认在 `codex-rs` 下运行 `cargo build -p codex-cli --release`
  - `CODEX_SKIP_BUILD=1` 和 `CODEX_SOURCE_BIN` 继续保留

### 本次不做的扩展

以下能力刻意不纳入本次改动：

- 自动安装 Rust toolchain 之外的系统工具
- 自动检测并安装 `brew`
- 自动安装或更新 `rg`
- 自动修改 shell 配置文件中的 PATH
- 平台特定的安装目录策略

这样可以确保改动范围严格围绕“源码一键安装跨平台化”。

## 文档更新

更新 `docs/install.md`：

- 将 “Ubuntu source install with backup” 改为 “macOS/Linux source install with backup”
- 示例命令改为 `./scripts/install/install-source.sh`
- 补充说明旧的 `install-ubuntu-source.sh` 仍可作为兼容入口使用

## 验证策略

### 低风险脚本验证

- `./scripts/install/install-source.sh --help`
- `./scripts/install/install-ubuntu-source.sh --help`

### 无副作用安装路径验证

通过环境变量绕过真实构建并安装到临时目录：

- `CODEX_SKIP_BUILD=1`
- `CODEX_SOURCE_BIN=<本地可执行文件>`
- `--install-path /tmp/.../codex`

目标是验证：

- macOS 平台检查路径正确
- 新旧脚本入口都可用
- 目标路径创建、备份和安装流程无异常

## 风险与兼容性

- 旧脚本改为包装层后，依赖其帮助文案的自动化可能看到文案变化
- macOS 默认仍安装到 `/usr/local/bin/codex`，在个别环境上可能需要 `sudo`
- 如果用户期待“顺带装好依赖和 PATH”，本次变更不会满足，需要后续单独设计
