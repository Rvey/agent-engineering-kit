---
name: react-next-performance
description: React 19 + Next.js performance patterns. Use when writing or reviewing client components, hooks, effects, memos, streaming UI, or canvas (React Flow) code. Covers effect hygiene, memo discipline, SSE batching, and storage I/O.
---

# React / Next.js Performance

## 1. Effects run — and re-run — more than you think

- Every `useEffect` MUST have a complete dep array. No bare `useEffect(() => {...})`
  (it fires after **every** render, including 60fps drag frames).
- Never put a fresh-identity array/object in deps (`filtered`, `runs`, `versions`).
  Derive a scalar first (`firstKey`, `hasActiveRun`, `versions.length`) and depend on that.
- Polling intervals: deps must be `[id, booleanFlag, stableCallbacks]` — never the
  selected-item id if selecting shouldn't reset the timer. Read the selected id via a ref inside the tick.
- Don't `setState` for the same data twice in one flow (e.g. a fetcher that already
  `setRuns` + another `setRuns` after awaiting it). One owner per state per flow.
- Prefer derived state and event handlers over effect chains. If you're syncing
  prop → state in an effect, you probably want `useState(() => ...)` initializer,
  a `key` prop, or computing during render instead.

## 2. Hot-path handlers must have stable identity

- Callbacks passed to ReactFlow (`onConnect`, `onNodesChange`) or list items must NOT
  close over `nodes`/`edges` arrays. Mirror to a ref (`nodesRef`) and read it inside.
- `send`-style callbacks: keep `busy`/`input` out of deps via refs where the function
  is passed to memoized children.

## 3. Streaming (SSE) — batch, cap, defer

- NEVER `setState` per token/event in a loop. Accumulate into a local array, commit once per chunk.
- Cap unbounded growth: logs, messages (`slice(-N)`), and anything stringified for display.
- NEVER `JSON.stringify` + `localStorage.setItem` synchronously per update.
  Ephemeral surfaces (playgrounds, previews) are memory-only by design; if
  persistence is ever introduced, write debounced (≥500ms) and skip
  non-visible placeholder content.
- NEVER `JSON.stringify(allLogs)` per render for a debug tab — render the tail only.

## 4. Memo discipline

- `useMemo` deps must be scalars or stable references. For array/object contents, hoist
  an explicit key (`arr.join("\u0000")`, `JSON.stringify(obj)`) into a named const with
  a comment — never inline the call in the dep array where reviewers can't see it.
- A memo that depends on `nodes` recomputes on every drag/keystroke. Keep the work
  inside proportional (single pass, early-out) and the output referentially stable
  when nothing relevant changed (return the input array unchanged when there's no work).

## 5. Canvas-heavy apps (React Flow)

- `displayNodes`-style projections must return the original array when there are no
  overlays, and only clone nodes that actually change.
- Typing in an inspector input calls `onUpdate` → `setNodes` → full canvas render.
  That's accepted, but the per-render work (coverage analysis, issue collection,
  variable sanitizing) must each be single-pass and memoized.
- `onlyRenderVisibleElements` stays on. Keep `nodeTypes`/`edgeTypes` module-level.

## 6. Review checklist (apply to every React PR)

1. [ ] No dep-less `useEffect`. No array/object identity in deps without a scalar key.
2. [ ] No `setState` in a per-token / per-event / per-frame loop — batched?
3. [ ] No sync storage I/O or full-list `JSON.stringify` in render or per-update effects.
4. [ ] Hot callbacks (`onConnect`, pollers, SSE handlers) stable across renders?
5. [ ] The repo's web lint/type gate is clean (hooks rules enforced — zero
   warnings is the bar).
