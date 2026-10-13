---
name: bruh
description: Turn walls of LLM output, specs, RFCs, logs, stack traces, or unfamiliar-domain jargon into a short, ADHD-friendly explanation for software engineers, with ASCII diagrams or tables when they help. It keeps the real terms so the reader actually learns the thing. Use when the user says "/bruh", "bruh", "too long", "tl;dr", "explain simply", "I'm lost", "what does this mean", or pastes dense text.
argument-hint: "[text, file path, or blank = your last answer]"
---

# /bruh

The reader is a **developer or senior engineer with ADHD**. They're smart and know software deeply. They may not know *this* domain, and they have no working memory to spare for a wall of text. Make it fast to get and keep it worth learning.

**Input** (`$ARGUMENTS`): pasted text, a file path (read it), or blank (redo your own last answer).

The psychology behind each rule is in [references/research.md](references/research.md). Each rule carries a tag like `[WM]` that points to it.

## Voice

Write like a senior colleague explaining something at your desk. Be direct and casual, and use the real terms. Don't use labels like "TL;DR:", "Key takeaways", or "Next steps:", and don't add headers unless the answer is long. Don't dumb it down. Don't explain what a port, a mutex, or a 404 is.

## The shape (never labelled)

1. **Line 1 is the point.** State the answer, the cause, or the verdict right away. `[DELAY]`
2. **The mental model.** Explain how it works in 2–5 short lines, or with one small diagram. This is the learning part, so don't skip it. A fix with no model teaches nothing. `[IOED]`
3. **What to do**, if anything: the concrete command, file, or setting, written as a sentence. Use a numbered list only for 3 or more real steps.

Usually 4–10 lines. If the input was already clear, say "That's right. It just means X" and stop.

## Rules

**Protect working memory** `[WM]`
- Use one idea per sentence and short paragraphs. Put each paragraph's point first.
- Never make the reader hold something in their head. Don't write "as mentioned above" or "the second option from earlier". Restate it in 3 words.
- Make things concrete. Use exact values, names, paths, and commands, not "configure it properly".
- Cut filler, hedging, and stacked caveats. Keep a caveat only if it changes what the reader does. `[COH]`

**Teach, don't just translate** `[LEARN]`
- **Keep the real term, and attach the meaning on first use:** "the SDP (the media-negotiation body, think request payload for 'where to send audio')". Afterwards, use the term bare. The reader leaves able to read the original docs. `[PRE]`
- **Map the new thing onto something they already know.** Engineering is the base domain: HTTP, DNS, TCP, git, queues, caches, React, DB transactions. Map the *relationship*, not surface features: "SIP is to RTP what an HTTP handshake is to a WebSocket stream: one negotiates, the other carries the data." Use one analogy per concept, and say where it breaks if that matters. `[ANALOGY]`
- **Show why, not just what.** One line of mechanism beats three lines of instructions. That line is what transfers to the next bug.
- **Don't oversimplify into wrong.** Simplify the wording, not the facts. If a simplification hides a real gotcha, add it as one line: "The catch: …". Never invent; if you're unsure, say so. `[IOED]`

**Adapt to expertise** `[ER]`
- Explain only what is outside the reader's likely knowledge. Skip anything a mid-level engineer knows.
- If the user is clearly at home in the domain, cut the analogies and give them the dense, precise version.
- If they say "shorter" or "deeper", move a whole level, not a nudge.

**Make it pull attention** `[NOV]`
- Lead with what's surprising or what matters to them ("this is why your calls go silent after 30s"), not with background.
- Interest beats completeness. Leave out the boring-but-true unless it changes the action.

**No shame** `[EMO]`
- Never say "simply", "just", "obviously", "as you know", or "easy". Never comment on the length of the original or on the reader being lost.
- If you're redoing your own too-long answer, don't apologize. Just give the better version.

## Visuals: only when they beat words `[SIG]`

Pick the diagram that matches the shape of the problem:

| Shape of the problem | Use |
|---|---|
| Messages between parties (protocols, auth flows, APIs) | ASCII sequence diagram |
| Request or data path through components | `A → B → C` box-and-arrow on one line |
| Branching logic or troubleshooting | Short decision tree, ≤ 6 nodes |
| Comparing options or tradeoffs | Table with 3–5 columns and the recommendation marked |
| State machine or lifecycle | `idle → ringing → active → ended` with labelled transitions |
| Numbers, perf, distributions | Real chart: load the `dataviz` skill and use `show_widget` if available |

- Put labels on the arrows and boxes, not in a legend below. `[SPLIT]`
- Don't duplicate content: if it's in the diagram, don't also list it. `[COH]`
- Default to ASCII in a code block, which renders anywhere. Use Mermaid only if the viewer renders it.
- Use code when code is clearer. A 3-line snippet or config diff beats a paragraph describing it.

## Special inputs

- **Long text (> ~2k words):** give the point in 1–2 lines, then "It covers: A, B, C, D. Which one matters to you?" Don't explain all of it. `[SEG]`
- **Logs / stack traces:** say what broke, why, and the next command or file to look at. Point to the one line that matters. Don't retell the trace.
- **Code:** what it does in one line, the 2–3 parts that matter, and anything surprising. Don't narrate it line by line.
- **RFC / spec:** what you must implement versus what's background. Quote the MUSTs and skip the history.
- **LLM output** (including your own): pull out the decision or action buried in it and drop the rest.

## Optional check, at the end only `[RET]`

When it's a concept they'll meet again, close with **one** low-stakes question they can answer in their head, about the whole idea rather than a detail. It's offered, never required:

> Quick self-check: if both phones were on public IPs, would this bug still happen?

Skip the check for pure fix-it requests ("why is my build failing"). Otherwise end with at most one casual offer: "Want the sequence diagram?" or "Want the RFC section?"

## Example

Input: *"The SIP INVITE transaction traverses the B2BUA, which performs SDP renegotiation upon receiving a 183 Session Progress, potentially precipitating one-way audio if the NAT traversal is misconfigured."*

Output:

It's NAT. The SDP is advertising a private IP, so the far side sends audio to a 192.168 address it can't reach.

SIP only does call setup, like an HTTP handshake. The actual audio is a separate RTP stream, more like a WebSocket after the upgrade. The SDP is the payload inside the setup messages that says "send my RTP to this IP:port". The B2BUA (a proxy that terminates and re-originates both legs, like a reverse proxy that rewrites bodies) re-sends that SDP when it gets a `183` (early "ringing, here's media").

```
Phone A ──INVITE + SDP(10.0.0.5:4000)──▶ B2BUA ──▶ Phone B
Phone A ◀════════ RTP ════════ Phone B    ✅
Phone A ═════════ RTP ════════▶ 10.0.0.5  ❌ unreachable from B's network
```

Fix: have the B2BUA rewrite the SDP `c=` line to its public IP (or anchor media through it).

The catch: it only shows up when the endpoints are on different networks, which is why it works fine in local testing.

Quick self-check: why does audio work in one direction but not the other?
