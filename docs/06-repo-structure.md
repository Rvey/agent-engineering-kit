# Repo structure & layering conventions

The kit's examples come from a monorepo that pair a Next.js app with a FastAPI
runtime and a shared contracts package. The **names** are specific; the
**principles** transfer to any stack.

## Reference layout

```
repo/
├── AGENTS.md                  # repo-wide agent routing + gates + hard rules
├── .agents/skills/            # vendored skills (travel with the repo)
├── .cursor/rules/             # glob-scoped rules for Cursor-compatible agents
├── apps/
│   ├── web/                   # Next.js app
│   │   ├── AGENTS.md          # web-only rules (compressed, points at root)
│   │   ├── app/               # App Router: thin pages that compose features
│   │   ├── components/        # ui/ primitives + feature UI
│   │   ├── features/          # hooks, mutations, selectors (not JSX dumps)
│   │   └── lib/               # env, API clients, domain utilities
│   └── runtime/               # FastAPI app
│       ├── app/
│       │   ├── api/           # thin routers: parse → service → respond
│       │   ├── services/      # business logic
│       │   ├── repositories/  # DB access only
│       │   ├── schemas/       # Pydantic request/response models
│       │   ├── models/        # ORM entities
│       │   └── core/          # settings, engine/session, lifespan
│       └── tests/             # mirror the package layout
├── packages/
│   └── shared/                # cross-app contracts: types, registry, compiler
├── docs/                      # decisions, reports, runbooks, test prompts
└── scripts/                   # dev/ops scripts (not application code)
```

## Layering rules (the part agents get wrong)

**Web app**

- Pages compose features; they don't hold business logic.
- `components/ui/` is for design-system primitives only — app code doesn't
  leak in.
- `features/` holds hooks/selectors/mutations; JSX belongs in components.
- The framework's API routes are a BFF, not a second backend: no domain
  business logic in route handlers.
- Prefer `@/` imports over deep relative chains (`../../../`).

**Runtime**

- Strict direction: `api/` → `services/` → `repositories/`. Never backwards;
  never DB calls in routers; never HTTP concerns in repositories.
- `main.py` stays wiring, not logic. No scattered `os.getenv` — settings live
  in one config module.
- Tests mirror the package layout; a test file's path tells you its owner.

**Shared contracts**

- One source of truth for anything both sides must agree on: node/registry
  metadata, connection rules, enums, validation.
- If the same rule exists in TypeScript and Python, name one as the mirror and
  put "keep in sync" in the change checklist — or generate one from the other.
- Never copy a rule into a component. Components call the registry/validator.

## Enforcement layering

A pattern worth stealing: **UI prevents, draft saves stay permissive, publish
is strict, and the server re-validates.**

1. Palette/menus only offer legal options.
2. Connection handlers reject illegal links at interaction time.
3. Draft saves accept half-built state (autosave must not fight the user).
4. Test/Publish runs full validation.
5. The API re-validates for forged payloads (`validateGraph` → compile-time
   boundary checks in both languages).

Agents extend the layers; they never skip one because "the UI prevents it".

## Instruction layering

| Layer | Scope | Lives in |
|---|---|---|
| Root `AGENTS.md` | Whole repo: routing, gates, hard rules | `AGENTS.md` |
| App rules | One app's stack conventions | `apps/<app>/AGENTS.md` |
| Glob rules | File-pattern-scoped (Cursor) | `.cursor/rules/*.mdc` |
| Workflows | Deep, on-demand procedures | `.agents/skills/<name>/SKILL.md` |
| Decisions | "Why" with a paper trail | `docs/` (ADR-style when needed) |

Rules flow downward and are never duplicated upward. An app-level `AGENTS.md`
is short: it points at the root for gates and adds only what is app-specific.

## Environment & ops hygiene

- `.env.example` is committed with placeholders; real env files are
  gitignored. Secrets never touch a remote; a leaked secret is rotated first,
  purged second.
- Deployment compose/env files mirror the dev ones: **when you change a
  service, env var, or healthcheck in dev, mirror it in the production file in
  the same change.** Drift here is how "it works locally" becomes an incident.
- Do not invent new top-level folders; put scripts in `scripts/`, tests next
  to the layout they mirror, docs in `docs/`.

## Adapting to another stack

Keep the skeleton, swap the names:

| Principle | Any-stack translation |
|---|---|
| `apps/web`, `apps/runtime`, `packages/shared` | `frontend/`, `backend/`, `shared/` — or `service-a/`, `service-b/`, `common/` |
| `app/api/` BFF | Next.js route handlers, BFF layer, or API gateway rules |
| Strict layered backend | routers → controllers → services → repositories, in any language |
| Shared contracts | OpenAPI/Protobuf/JSON Schema or a shared types package |
| Instruction layering | Root `AGENTS.md` + per-package `AGENTS.md` + scoped rules |

The invariant: **one owner per rule, one gate per layer, contracts defined
once.**

## The kit repository itself

The kit follows its own layering: instructions route, scripts behave, docs
explain. Nothing is stated twice.

```
agent-engineering-kit/
├── AGENTS.md                    # this repo's real instructions (no placeholders)
├── templates/
│   ├── AGENTS.template.md       # the shape copied into other repositories
│   ├── verify/                  # verify.sh starters: shell, node, python
│   ├── hooks/pre-commit         # the fast-gate hook
│   └── github/                  # PR template, policy + gates workflows, CODEOWNERS
├── .agents/skills/              # vendored skills, one directory per skill
├── scripts/                     # bootstrap, install-hooks, setup-check, lint, new-skill
├── tests/setup-smoke.sh         # end-to-end install/behaviour regression
├── docs/                        # playbooks and the troubleshooting guide
└── .github/workflows/kit.yml    # the kit's own CI: lint, actionlint, self-check, smoke
```

Two rules keep this layout honest. Behaviour lives in `scripts/` and is proven
by `tests/`; every instruction file points at those commands instead of
describing them again. And `templates/` is the only place other-project
content belongs — if a file is generic, it ships from there.
