# Performance guards (learned from real incidents)

These eight rules exist because each one was violated in production first.
They are hard rules, not suggestions: agents reintroduce every one of these
bug classes by default unless the rule is in front of them. The examples are
React/TypeScript, but the classes generalize to any UI framework with
reactive effects, streaming data, or canvas rendering.

Keep your own version of this list in `AGENTS.md` and add to it every time an
incident gets through.

---

## 1. No dep-less effects

**Rule:** Every effect has a complete dependency array. No
`useEffect(() => { ... })` without deps.

**The incident:** A mirror effect without a dep array fired on every frame of
a canvas drag, re-syncing state ~60×/second and stuttering the whole editor.

**How to spot it:** A bare `useEffect(` immediately followed by a body and no
second argument. Reviewers grep for `useEffect(() =>` and check each one.

**Fix:** Add the complete dep array. If the effect genuinely runs once, say so
with `[]` and a comment naming why.

## 2. No fresh-identity arrays/objects in dependency arrays

**Rule:** Never put a value in a dep array unless its identity is stable
across renders. Derive a scalar key first.

**The incident:** `useEffect(..., [filteredRuns])` re-ran on every render
because `.filter()` returns a new array each time — polling restarted
constantly and the UI flickered.

**Fix:** Hoist the derivation into a named const and depend on a scalar:

```ts
// bad: new array identity every render
useEffect(() => { ... }, [runs.filter(r => r.active)]);

// good: scalar key, stable
const activeRunKey = runs.filter(r => r.active).map(r => r.id).join("|");
useEffect(() => { ... }, [activeRunKey]);
```

For objects, keep the serialization in a named const with a comment — never
inline `JSON.stringify(obj)` in the dep array where reviewers can't see the
cost.

## 3. No `setState` per stream token / event / frame

**Rule:** Streaming data accumulates locally and commits once per chunk.
Never one state update per token, SSE event, or animation frame.

**The incident:** Chat streaming called `setMessages` per token. Every token
re-rendered the whole thread — hundreds of renders per reply — and long
conversations degraded until typing lagged.

**Fix:** Buffer into a local array/ref, flush on an interval or chunk
boundary, cap list growth (`slice(-N)`), and never stringify the full list
per render (render the tail only).

## 4. No synchronous storage I/O per update

**Rule:** No `localStorage.setItem` / file writes / network sync per state
update. If persistence is required, debounce it (≥500ms).

**The incident:** Chat history was persisted synchronously on every message
update. With streaming, that meant dozens of synchronous writes per reply, on
the main thread.

**Fix:** Persist debounced, skip non-visible placeholder content, and prefer
memory-only for ephemeral surfaces (a playground chat that resets on reload is
often the *correct* design).

## 5. No double `setState` for the same data in one flow

**Rule:** One owner per state per flow. If a fetcher sets state internally,
don't set it again after awaiting the fetcher.

**The incident:** A loader called `setRuns()` internally, then the caller
awaited it and called `setRuns()` again with the same data — two renders per
load, and a stale-closure race where the second write could clobber newer
data.

**Fix:** Pick the owner. Fetcher-owns-state means callers just `await`. If a
caller needs the data too, return it and let the caller set it once.

## 6. Hot-path callbacks must have stable identity

**Rule:** Handlers passed to canvas libraries, pollers, or memoized children
must not close over large arrays/objects. Read latest state through refs.

**The incident:** `onConnect`/`onNodesChange` closed over the `nodes` array,
so the callbacks changed identity on every node change; the canvas
re-subscribed its handlers each time and mid-interaction updates were dropped.

**Fix:**

```ts
const nodesRef = useRef(nodes);
nodesRef.current = nodes;                     // keep fresh
const onConnect = useCallback((c) => {
  // read nodesRef.current, not nodes
}, []);                                       // stable identity
```

## 7. Polling timers depend on `[id, booleanFlag, stableCallbacks]`

**Rule:** Selecting an item must not reset its polling interval. Read the
selection via a ref inside the tick.

**The incident:** The poll effect depended on `selectedRunId`, so clicking
between runs tore down and re-created the interval every time — up to a full
poll delay of dead time per click, and a request storm when clicking quickly.

**Fix:** Deps: the resource id, a boolean "active" flag, and stable callbacks.
Read mutable selection state from a ref inside the tick.

## 8. Projections return input identity when there is no work

**Rule:** Derived collections return the original reference when nothing
changed and clone only the items that changed.

**The incident:** A `displayNodes` projection always `.map`'d a fresh array.
React Flow re-rendered every node on every keystroke in an unrelated inspector
field.

**Fix:**

```ts
if (issues.length === 0 && overlay === null) return nodes; // identity
return nodes.map(n => (changed.has(n.id) ? { ...n, data: ... } : n));
```

---

## Canvas / heavy-UI specifics

- Keep `nodeTypes`/`edgeTypes` module-level (never recreated in render).
- `React.memo` custom nodes; split selection state from graph state so
  selecting a node doesn't re-render the graph.
- Turn on only-render-visible-elements for large graphs.
- Per-render work (coverage analysis, issue collection, sanitizing) must be
  single-pass, memoized, and early-out.
- Memo deps must be scalars or stable references; a memo depending on the
  nodes array recomputes on every drag — keep it proportional and
  referentially stable.

## Review checklist (apply to every UI PR)

1. [ ] No dep-less effects; no array/object identity in deps without a scalar key.
2. [ ] No `setState` in a per-token / per-event / per-frame loop — batched?
3. [ ] No sync storage I/O or full-list `JSON.stringify` per update.
4. [ ] Hot callbacks (canvas handlers, pollers, stream handlers) stable across renders?
5. [ ] Projections return input identity when idle; clones only changed items.
6. [ ] The repo's lint/type gate is clean (hooks rules enforced — zero warnings is the bar).
