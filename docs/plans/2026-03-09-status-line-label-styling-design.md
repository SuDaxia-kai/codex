# Status Line Label Styling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the default status line easier to scan by adding small icons and category colors to the `model`, `dir`, `permission`, and `context` labels.

**Architecture:** Keep the existing status line layout and values, but centralize label rendering so the default segments can prepend compact Unicode icons and colored labels while leaving values readable. Lock the behavior with a focused `chatwidget` test that checks both the rendered text and the label colors.

**Tech Stack:** Rust, ratatui, existing `codex-tui` status line tests

---

### Task 1: Lock the label styling behavior

**Files:**
- Modify: `codex-rs/tui/src/chatwidget/tests.rs`

**Step 1: Write the failing test**

Add a test that asserts the default status line contains the new icon-prefixed labels and that each label span uses the intended foreground color.

**Step 2: Run test to verify it fails**

Run: `cargo test -p codex-tui default_status_line_uses_colored_icon_labels --manifest-path codex-rs/Cargo.toml`

Expected: FAIL because the current labels are plain gray text without icons.

### Task 2: Implement the minimal styling helpers

**Files:**
- Modify: `codex-rs/tui/src/chatwidget.rs`

**Step 3: Write minimal implementation**

Add a small helper for colored status line labels and update the model, directory, permission, and context segments to use icon-prefixed labels.

**Step 4: Run test to verify it passes**

Run: `cargo test -p codex-tui default_status_line_uses_colored_icon_labels --manifest-path codex-rs/Cargo.toml`

Expected: PASS.

### Task 3: Run focused regression coverage

**Files:**
- Modify: `codex-rs/tui/src/chatwidget.rs`
- Modify: `codex-rs/tui/src/chatwidget/tests.rs`

**Step 5: Run targeted verification**

Run: `cargo test -p codex-tui chatwidget --manifest-path codex-rs/Cargo.toml`

Expected: `chatwidget` tests pass with the new status line styling.
