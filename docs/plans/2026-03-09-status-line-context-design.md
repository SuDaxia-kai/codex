# Status Line Context Consistency Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the TUI status line context usage match the `/status` context card by showing current context usage instead of cumulative session usage.

**Architecture:** Keep the existing status line structure and labels, but change the context usage calculation in `ChatWidget` to derive its token count from the latest in-context usage instead of the accumulated total. Add a focused regression test in the existing `chatwidget` test module to lock the displayed value to the `/status` card semantics.

**Tech Stack:** Rust, ratatui, existing `codex-tui` tests

---

### Task 1: Lock the desired status-line behavior

**Files:**
- Modify: `codex-rs/tui/src/chatwidget/tests.rs`

**Step 1: Write the failing test**

Add a test that feeds `TokenUsageInfo` with different `total_token_usage` and `last_token_usage` values, then asserts that the status line uses the current in-context value.

**Step 2: Run test to verify it fails**

Run: `cargo test -p codex-tui status_line_context_uses_current_context_tokens --manifest-path codex-rs/Cargo.toml`

Expected: FAIL because the current implementation uses cumulative usage.

### Task 2: Implement the minimal calculation change

**Files:**
- Modify: `codex-rs/tui/src/chatwidget.rs`

**Step 3: Write minimal implementation**

Update the status-line context usage helper so the displayed used token count comes from the latest in-context usage, matching `/status`.

**Step 4: Run test to verify it passes**

Run: `cargo test -p codex-tui status_line_context_uses_current_context_tokens --manifest-path codex-rs/Cargo.toml`

Expected: PASS.

### Task 3: Run focused verification

**Files:**
- Modify: `codex-rs/tui/src/chatwidget.rs`
- Modify: `codex-rs/tui/src/chatwidget/tests.rs`

**Step 5: Run targeted verification**

Run: `cargo test -p codex-tui chatwidget --manifest-path codex-rs/Cargo.toml`

Expected: relevant `chatwidget` tests pass.
