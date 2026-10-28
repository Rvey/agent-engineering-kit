#!/usr/bin/env bash
# bootstrap.sh — install the Agent Engineering Kit into a repository.
#
# Usage:
#   scripts/bootstrap.sh                          (no arguments: guided menu in a terminal)
#   scripts/bootstrap.sh [options] <target-dir>
#   scripts/bootstrap.sh <target-dir> [options]   (legacy order still works)
#
# Options:
#   --interactive            prompt for preset + component selection.
#                            Uses gum/fzf when available, pure-bash fallback otherwise.
#   --preset <name>          minimal | standard | full. Non-interactive preset.
#                            minimal:  AGENTS.md + agents-md, full-setup + setup tools.
#                            standard: minimal + boost-prompt, context-engineering,
#                                      deslop, documentation-and-adrs,
#                                      security-audit, test-audit + .github/.
#                            full:     every skill + setup tools + .github/
#                                      (same as no --preset; --with-cursor still opt-in).
#   --skills <csv|all>       comma-separated skill subset (e.g. --skills deslop,test-audit).
#                            Overrides the preset skill list. Use --list-skills to see names.
#   --list-skills            print available skill names (one per line) and exit.
#   --force                  overwrite matching kit paths (never removes local additions).
#   --with-cursor            also copy .cursor/rules/ templates.
#   --skills-only            copy only skills (no AGENTS.md, setup tools, or .github/).
#   --no-agents-md           skip the AGENTS.md template copy.
#   --no-github              skip the .github/ loop-enforcement files.
#   --dry-run                print every copy/skip decision and write nothing.
#   --yes                    skip the final confirmation prompt in --interactive mode.
#   --update                 refresh an existing install: compare installed skills with
#                            the kit, then prompt to update changed skills, add all new
#                            skills, or pick skill by skill. Touches only .agents/skills/.
#                            Non-interactive: --update --yes (update + add everything) or
#                            --update --skills <csv|all> (just those). Works with --dry-run.
#
# What it does:
#   - copies templates/AGENTS.template.md into <target-dir>/AGENTS.md (skipped
#     if present unless --force). The template is a shape, not content: the
#     next step is generating the project file with the agents-md skill.
#   - copies selected skills into <target-dir>/.agents/skills/
#   - copies the loop-enforcement files into <target-dir>/.github/
#     (PR template, no-AI policy workflow + check script, CODEOWNERS example)
#   - copies .cursor/rules/ templates when --with-cursor is given
#   - with --skills-only, copies only the skills (no AGENTS.md)
#   - with --no-github, skips the .github/ files (non-GitHub hosts)
#   - with --dry-run, prints every copy/skip decision and writes nothing
#
# Nothing is deleted. --force overwrites matching kit paths, not extra files in skill directories.
# With no arguments in a terminal it opens a menu (install, update skills, list skills).
# Any argument keeps it non-interactive so CI/scripts keep working; --interactive opts in.
# AGENT_KIT_NO_TTY=1 forces the no-terminal behaviour (prompts fail closed).
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NO_ARGS=0
if [[ $# -eq 0 ]]; then NO_ARGS=1; fi
TARGET=""
FORCE=0
WITH_CURSOR=0
SKILLS_ONLY=0
WITH_GITHUB=1
GITHUB_EXPLICIT=0
SKIP_AGENTS=0
DRY=0
INTERACTIVE=0
PRESET=""
SKILLS_FILTER=""
LIST_ONLY=0
ASSUME_YES=0
UPDATE=0

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
  exit 0
fi

# Parse args in any order: first non-flag value is the target directory.
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --with-cursor) WITH_CURSOR=1; shift ;;
    --skills-only) SKILLS_ONLY=1; shift ;;
    --no-github) WITH_GITHUB=0; GITHUB_EXPLICIT=1; shift ;;
    --no-agents-md) SKIP_AGENTS=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --interactive) INTERACTIVE=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --update) UPDATE=1; shift ;;
    --list-skills) LIST_ONLY=1; shift ;;
    --preset)
      if [[ $# -lt 2 ]]; then echo "error: --preset needs a value: minimal|standard|full" >&2; exit 1; fi
      PRESET="$2"; shift 2 ;;
    --preset=*) PRESET="${1#--preset=}"; shift ;;
    --skills)
      if [[ $# -lt 2 ]]; then echo "error: --skills needs a value (csv or 'all')" >&2; exit 1; fi
      SKILLS_FILTER="$2"; shift 2 ;;
    --skills=*) SKILLS_FILTER="${1#--skills=}"; shift ;;
    --help|-h)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
    --*) echo "error: unknown option: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$TARGET" ]]; then TARGET="$1"; else ARGS+=("$1"); fi
      shift ;;
  esac
done
if [[ "${#ARGS[@]}" -gt 0 ]]; then
  echo "error: unexpected argument: ${ARGS[0]}" >&2
  exit 1
fi

list_skill_names() {
  local d
  for d in "$KIT_DIR"/.agents/skills/*/; do
    [[ -d "$d" ]] || continue
    basename "$d"
  done | sort
}

if [[ "$LIST_ONLY" -eq 1 ]]; then
  list_skill_names
  exit 0
fi

if [[ "$UPDATE" -eq 1 && ( "$INTERACTIVE" -eq 1 || -n "$PRESET" ) ]]; then
  echo "error: --update cannot be combined with --interactive or --preset" >&2
  exit 1
fi

if [[ -n "$PRESET" ]]; then
  case "$PRESET" in
    minimal|standard|full) ;;
    *) echo "error: unknown preset: $PRESET (expected minimal|standard|full)" >&2; exit 1 ;;
  esac
fi

if [[ -n "$SKILLS_FILTER" && "$SKILLS_FILTER" != "all" ]]; then
  # Validate early: every name must match an existing skill directory.
  old_ifs="$IFS"
  IFS=','
  # Word-splitting the csv on commas is the intent here.
  # shellcheck disable=SC2206
  parts=($SKILLS_FILTER)
  IFS="$old_ifs"
  for raw in "${parts[@]}"; do
    name="$(printf '%s' "$raw" | tr -d '[:space:]')"
    if [[ -z "$name" ]]; then echo "error: empty skill name in --skills '$SKILLS_FILTER'" >&2; exit 1; fi
    if [[ ! -d "$KIT_DIR/.agents/skills/$name" ]]; then
      echo "error: unknown skill: $name (see --list-skills)" >&2
      exit 1
    fi
    case "$name" in
      *[/.]*) echo "error: invalid skill name: $name" >&2; exit 1 ;;
    esac
  done
fi

has_gum() { command -v gum >/dev/null 2>&1; }
has_fzf() { command -v fzf >/dev/null 2>&1; }

# Fail closed when no controlling terminal exists, so piped/CI input can
# never silently accept defaults and write files.
has_tty() {
  [[ "${AGENT_KIT_NO_TTY:-0}" != 1 ]] && ( : < /dev/tty ) 2>/dev/null
}

require_tty() {
  local mode="${1:---interactive}"
  if ! has_tty; then
    echo "error: $mode needs a terminal (/dev/tty is not available)" >&2
    exit 1
  fi
}

read_from_tty() {
  local var_name="$1"
  local reply_val=""
  if [[ -t 0 ]]; then
    if ! read -r reply_val; then
      echo "error: input cancelled (EOF on stdin)" >&2
      exit 1
    fi
  else
    if ! read -r reply_val < /dev/tty; then
      echo "error: input cancelled (EOF on /dev/tty)" >&2
      exit 1
    fi
  fi
  printf -v "$var_name" '%s' "$reply_val"
}

prompt_yesno() {
  local question="$1" default="$2" answer=""
  local suffix="Y/n"
  if [[ "$default" == "n" ]]; then suffix="y/N"; fi
  while true; do
    printf '%s [%s]: ' "$question" "$suffix" >&2
    read_from_tty answer
    # Trim surrounding whitespace without external tools.
    answer="$(printf '%s' "$answer" | tr -d '[:space:]')"
    if [[ -z "$answer" ]]; then answer="$default"; fi
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
      *) echo "  please answer y or n." >&2 ;;
    esac
  done
}

prompt_preset() {
  local choice=""
  if has_gum && [[ -t 1 ]]; then
    if choice="$(printf 'minimal\nstandard\nfull\n' | gum choose --header "Pick a preset")"; then
      if [[ -n "$choice" ]]; then printf '%s' "$choice"; return 0; fi
    fi
    echo "  (picker skipped — falling back to numbered prompt)" >&2
  fi
  if has_fzf && [[ -t 1 ]]; then
    if choice="$(printf 'minimal\nstandard\nfull\n' | fzf --prompt="Preset> " --height=7 --reverse)"; then
      if [[ -n "$choice" ]]; then printf '%s' "$choice"; return 0; fi
    fi
    echo "  (picker skipped — falling back to numbered prompt)" >&2
  fi
  echo "Pick a preset:" >&2
  echo "  1) minimal  — AGENTS.md + agents-md, full-setup + setup tools" >&2
  echo "  2) standard — minimal + boost-prompt, context-engineering, deslop," >&2
  echo "                documentation-and-adrs, security-audit, test-audit + .github/" >&2
  echo "  3) full     — every skill + setup tools + .github/" >&2
  printf 'Enter 1/2/3 [2]: ' >&2
  read_from_tty choice
  case "$choice" in
    1|minimal) printf 'minimal' ;;
    3|full) printf 'full' ;;
    ""|2|standard) printf 'standard' ;;
    *) echo "error: invalid preset choice: $choice" >&2; exit 1 ;;
  esac
}

prompt_skills() {
  local all_names="$1" preselected="$2" choice="" out=""
  if has_gum && [[ -t 1 ]]; then
    # gum choose --no-limit prints one selection per line on stdout.
    # Empty output with exit 0 means "keep preset"; failure falls back.
    if out="$(printf '%s\n' "$all_names" | gum choose --no-limit --header "Pick skills (Space to toggle, Enter to confirm — Esc for numbered list)")"; then
      printf '%s' "$out"
      return 0
    fi
    echo "  (picker skipped — falling back to numbered prompt)" >&2
  fi
  if has_fzf && [[ -t 1 ]]; then
    if out="$(printf '%s\n' "$all_names" | fzf --multi --prompt="Skills> " --height=16 --reverse)"; then
      printf '%s' "$out"
      return 0
    fi
    echo "  (picker skipped — falling back to numbered prompt)" >&2
  fi
  echo "Available skills:" >&2
  echo "$all_names" | awk '{ printf "  %d) %s\n", NR, $0 }' >&2
  echo "Preselected by preset: ${preselected:-<none>}" >&2
  printf "Enter numbers (e.g. 1 3 5), names, 'all', or Enter to keep preset: " >&2
  read_from_tty choice
  if [[ -z "$choice" ]]; then return 0; fi
  if [[ "$choice" == "all" ]]; then printf '%s' "$all_names"; return 0; fi
  # Resolve numbers/names against the numbered skill list.
  out=""
  for token in $choice; do
    token="$(printf '%s' "$token" | tr -d ',[:space:]')"
    [[ -n "$token" ]] || continue
    if [[ "$token" =~ ^[0-9]+$ ]]; then
      resolved="$(printf '%s\n' "$all_names" | sed -n "${token}p")"
      if [[ -z "$resolved" ]]; then echo "error: skill number out of range: $token" >&2; exit 1; fi
      out="$out $resolved"
    else
      if [[ ! -d "$KIT_DIR/.agents/skills/$token" ]]; then
        echo "error: unknown skill: $token (see --list-skills)" >&2; exit 1
      fi
      out="$out $token"
    fi
  done
  printf '%s' "$out"
}

# Main menu for a bare run. Defaults to "update" when the current directory
# already has a kit install, otherwise "install".
prompt_main_action() {
  local default="$1" choice=""
  local menu="install  — set up the kit in a repository (guided)
update   — update changed skills or add new ones
list     — show the skills this kit ships
quit"
  if has_gum && [[ -t 1 ]]; then
    if choice="$(printf '%s\n' "$menu" | gum choose --header "Agent Engineering Kit — what do you want to do?" --selected "$(printf '%s\n' "$menu" | grep "^$default ")")"; then
      if [[ -n "$choice" ]]; then printf '%s' "${choice%% *}"; return 0; fi
    fi
    echo "  (picker skipped — falling back to numbered prompt)" >&2
  fi
  if has_fzf && [[ -t 1 ]]; then
    if choice="$(printf '%s\n' "$menu" | fzf --prompt="Action> " --height=8 --reverse)"; then
      if [[ -n "$choice" ]]; then printf '%s' "${choice%% *}"; return 0; fi
    fi
    echo "  (picker skipped — falling back to numbered prompt)" >&2
  fi
  local default_num=1
  if [[ "$default" == "update" ]]; then default_num=2; fi
  echo "Agent Engineering Kit — what do you want to do?" >&2
  printf '%s\n' "$menu" | awk '{ printf "  %d) %s\n", NR, $0 }' >&2
  printf 'Enter 1-4 [%s]: ' "$default_num" >&2
  read_from_tty choice
  choice="$(printf '%s' "$choice" | tr -d '[:space:]')"
  if [[ -z "$choice" ]]; then choice="$default_num"; fi
  case "$choice" in
    1|install) printf 'install' ;;
    2|update) printf 'update' ;;
    3|list) printf 'list' ;;
    4|q|quit) printf 'quit' ;;
    *) echo "error: invalid choice: $choice" >&2; exit 1 ;;
  esac
}

if [[ "$NO_ARGS" -eq 1 ]] && has_tty; then
  default_action="install"
  if [[ -d ./.agents/skills ]]; then default_action="update"; fi
  action="$(prompt_main_action "$default_action")"
  case "$action" in
    list) list_skill_names; exit 0 ;;
    quit) echo "bye." >&2; exit 0 ;;
    install) INTERACTIVE=1 ;;
    update) UPDATE=1 ;;
  esac
  printf 'Target directory [.]: ' >&2
  read_from_tty TARGET
  if [[ -z "$TARGET" ]]; then TARGET="."; fi
fi

if [[ "$INTERACTIVE" -eq 1 ]]; then
  require_tty
  if [[ -z "$TARGET" ]]; then
    printf 'Target directory: ' >&2
    read_from_tty TARGET
  fi
  if [[ -z "$PRESET" ]]; then
    PRESET="$(prompt_preset)"
    echo "  preset: $PRESET" >&2
  fi
  # Preset defaults for the toggles below (explicit flags win).
  case "$PRESET" in
    minimal)
      if [[ "$GITHUB_EXPLICIT" -eq 0 ]]; then WITH_GITHUB=0; fi
      if [[ -z "$SKILLS_FILTER" ]]; then SKILLS_FILTER="agents-md,full-setup"; fi
      ;;
    standard)
      if [[ "$GITHUB_EXPLICIT" -eq 0 ]]; then WITH_GITHUB=1; fi
      if [[ -z "$SKILLS_FILTER" ]]; then
        SKILLS_FILTER="agents-md,full-setup,boost-prompt,context-engineering,deslop,documentation-and-adrs,security-audit,test-audit"
      fi
      ;;
    full)
      if [[ "$GITHUB_EXPLICIT" -eq 0 ]]; then WITH_GITHUB=1; fi
      if [[ -z "$SKILLS_FILTER" ]]; then SKILLS_FILTER="all"; fi
      ;;
  esac
  all_names="$(list_skill_names | tr '\n' ' ')"
  # Splitting the space-separated skill list is intentional.
  # shellcheck disable=SC2206
  all_array=($all_names)
  all_nl="$(printf '%s\n' "${all_array[@]}")"
  picked="$(prompt_skills "$all_nl" "$SKILLS_FILTER")"
  if [[ -n "$picked" ]]; then
    # Normalize newlines/extra spaces to a comma list for the shared validator path.
    SKILLS_FILTER="$(printf '%s' "$picked" | tr '\n' ',' | tr -s ' ,' ',,' | sed 's/^,//; s/,$//; s/,,*/,/g')"
  fi
  if [[ "$SKILLS_ONLY" -eq 0 && "$SKIP_AGENTS" -eq 0 ]]; then
    if ! prompt_yesno "Include AGENTS.md template?" "y"; then SKIP_AGENTS=1; fi
  fi
  if [[ "$GITHUB_EXPLICIT" -eq 0 && "$SKILLS_ONLY" -eq 0 ]]; then
    if [[ "$WITH_GITHUB" -eq 1 ]]; then
      if ! prompt_yesno "Include .github/ loop-enforcement files?" "y"; then WITH_GITHUB=0; fi
    else
      if prompt_yesno "Include .github/ loop-enforcement files?" "n"; then WITH_GITHUB=1; fi
    fi
  fi
  if [[ "$WITH_CURSOR" -eq 0 ]]; then
    if prompt_yesno "Include Cursor rule templates?" "n"; then WITH_CURSOR=1; fi
  fi
  if [[ "$DRY" -eq 0 && "$ASSUME_YES" -eq 0 ]]; then
    echo "" >&2
    echo "Summary: preset=$PRESET skills=${SKILLS_FILTER:-all} github=$WITH_GITHUB cursor=$WITH_CURSOR force=$FORCE" >&2
    if ! prompt_yesno "Proceed with install?" "y"; then echo "cancelled." >&2; exit 1; fi
  fi
else
  # Non-interactive preset defaults (explicit flags still win).
  if [[ -n "$PRESET" && -z "$SKILLS_FILTER" ]]; then
    case "$PRESET" in
      minimal) SKILLS_FILTER="agents-md,full-setup" ;;
      standard) SKILLS_FILTER="agents-md,full-setup,boost-prompt,context-engineering,deslop,documentation-and-adrs,security-audit,test-audit" ;;
      full) SKILLS_FILTER="all" ;;
    esac
  fi
  if [[ -n "$PRESET" && "$GITHUB_EXPLICIT" -eq 0 ]]; then
    case "$PRESET" in
      minimal) WITH_GITHUB=0 ;;
      standard|full) WITH_GITHUB=1 ;;
    esac
  fi
fi

if [[ -z "$TARGET" ]]; then
  echo "error: usage: $0 [options] <target-dir> [--force] [--with-cursor] [--skills-only] [--no-github] [--dry-run]" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "error: target directory does not exist: $TARGET" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd -P)"
if [[ "$UPDATE" -eq 1 ]]; then
  echo "Updating Agent Engineering Kit skills"
else
  echo "Installing Agent Engineering Kit"
fi
if [[ -n "$PRESET" ]]; then echo "  preset: $PRESET"; fi
if [[ -n "$SKILLS_FILTER" && "$SKILLS_FILTER" != "all" ]]; then echo "  skills: $SKILLS_FILTER"; fi
echo "  from: $KIT_DIR"
echo "  into: $TARGET"
echo

copy_file() {
  local src="$1" dest="$2"
  local parent
  parent="$(dirname "$dest")"
  while [[ "$parent" != "$TARGET" ]]; do
    if [[ -L "$parent" ]]; then
      echo "error: refusing symlink parent: $parent" >&2
      exit 1
    fi
    parent="$(dirname "$parent")"
  done
  if [[ -L "$dest" ]]; then
    echo "error: refusing symlink destination: $dest" >&2
    exit 1
  fi
  if [[ -d "$dest" ]]; then
    echo "error: expected a file destination: $dest" >&2
    exit 1
  fi
  # cp writes into the existing inode, so --force must not follow a hard
  # link (or open a FIFO/device) to a file outside the kit's ownership.
  if [[ -e "$dest" && "$FORCE" -eq 1 ]] \
    && [[ ! -f "$dest" || -n "$(find "$dest" -prune -links +1)" ]]; then
    echo "error: refusing hard-linked or non-regular destination: $dest" >&2
    exit 1
  fi
  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    echo "  skip   $(basename "$dest") (exists — use --force to overwrite)"
  elif [[ "$DRY" -eq 1 ]]; then
    echo "  plan   ${dest#"$TARGET"/}"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  copy   ${dest#"$TARGET"/}"
  fi
}

# Kit files of one skill that are missing or differ in the target, one per line.
skill_changed_files() {
  local name="$1" src rel
  while IFS= read -r -d '' src; do
    rel="${src#"$KIT_DIR"/}"
    if [[ ! -f "$TARGET/$rel" ]] || ! cmp -s "$src" "$TARGET/$rel"; then
      printf '%s\n' "$rel"
    fi
  done < <(find "$KIT_DIR/.agents/skills/$name" -type f -print0)
}

apply_skill_update() {
  local name="$1" rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    copy_file "$KIT_DIR/$rel" "$TARGET/$rel"
  done < <(skill_changed_files "$name")
}

run_update() {
  local name count choice
  local changed=() added=() current=() selected=()
  if [[ ! -d "$TARGET/.agents/skills" ]]; then
    echo "error: no kit install found in $TARGET (.agents/skills/ missing) — run bootstrap without --update first" >&2
    exit 1
  fi
  while IFS= read -r name; do
    if [[ -L "$TARGET/.agents/skills/$name" ]]; then
      echo "error: refusing symlink skill directory: $name" >&2
      exit 1
    fi
    if [[ ! -d "$TARGET/.agents/skills/$name" ]]; then
      added+=("$name")
    elif [[ -n "$(skill_changed_files "$name")" ]]; then
      changed+=("$name")
    else
      current+=("$name")
    fi
  done < <(list_skill_names)

  echo "Skill status:"
  for name in ${changed[@]+"${changed[@]}"}; do
    count="$(skill_changed_files "$name" | wc -l | tr -d ' ')"
    echo "  update $name ($count file(s) differ from the kit)"
  done
  for name in ${added[@]+"${added[@]}"}; do echo "  new    $name"; done
  echo "  ok     ${#current[@]} installed skill(s) already up to date"
  echo

  if [[ -n "$SKILLS_FILTER" ]]; then
    if [[ "$SKILLS_FILTER" == "all" ]]; then
      selected=(${changed[@]+"${changed[@]}"} ${added[@]+"${added[@]}"})
    else
      # Splitting the validated csv is intentional.
      # shellcheck disable=SC2207
      selected=($(printf '%s' "$SKILLS_FILTER" | tr ',' ' '))
    fi
  elif [[ "$ASSUME_YES" -eq 1 ]]; then
    selected=(${changed[@]+"${changed[@]}"} ${added[@]+"${added[@]}"})
  elif [[ "${#changed[@]}" -eq 0 && "${#added[@]}" -eq 0 ]]; then
    echo "Everything is up to date."
    return 0
  else
    require_tty "--update without --yes or --skills"
    echo "What do you want to do?" >&2
    echo "  1) Update installed skills (${#changed[@]}) — overwrites local edits to kit files, keeps extra files" >&2
    echo "  2) Add all new skills (${#added[@]})" >&2
    echo "  3) Update and add everything ($(( ${#changed[@]} + ${#added[@]} )))" >&2
    echo "  4) Choose skill by skill" >&2
    echo "  5) Cancel" >&2
    printf 'Enter 1-5 [3]: ' >&2
    read_from_tty choice
    case "$(printf '%s' "$choice" | tr -d '[:space:]')" in
      1) selected=(${changed[@]+"${changed[@]}"}) ;;
      2) selected=(${added[@]+"${added[@]}"}) ;;
      ""|3) selected=(${changed[@]+"${changed[@]}"} ${added[@]+"${added[@]}"}) ;;
      4)
        for name in ${changed[@]+"${changed[@]}"}; do
          if prompt_yesno "Update $name?" "y"; then selected+=("$name"); fi
        done
        for name in ${added[@]+"${added[@]}"}; do
          if prompt_yesno "Add $name?" "n"; then selected+=("$name"); fi
        done
        ;;
      5) echo "cancelled." >&2; exit 1 ;;
      *) echo "error: invalid choice: $choice" >&2; exit 1 ;;
    esac
  fi

  if [[ "${#selected[@]}" -eq 0 ]]; then
    echo "Nothing selected — no changes."
    return 0
  fi
  # Updating means replacing kit files; copy_file still refuses symlinks and hard links.
  FORCE=1
  [[ "$DRY" -eq 1 ]] || mkdir -p "$TARGET/.agents/skills"
  for name in "${selected[@]}"; do
    if [[ -L "$TARGET/.agents/skills/$name" ]]; then
      echo "error: refusing symlink skill directory: $name" >&2
      exit 1
    fi
    if [[ -z "$(skill_changed_files "$name")" ]]; then
      echo "  ok     $name (already up to date)"
      continue
    fi
    apply_skill_update "$name"
  done
  cat <<'NEXT'

Done. For any skill you added, merge its routing row from the kit's
templates/AGENTS.template.md into your AGENTS.md (or ask your agent to).
Then check readiness with bash .agents/setup-check.sh .
NEXT
}

if [[ "$UPDATE" -eq 1 ]]; then
  run_update
  exit 0
fi

# Resolve the skill subset once: "all"/empty means every vendored skill.
SELECTED_SKILLS=""
if [[ -z "$SKILLS_FILTER" || "$SKILLS_FILTER" == "all" ]]; then
  SELECTED_SKILLS="$(list_skill_names | tr '\n' ' ')"
else
  SELECTED_SKILLS="$(printf '%s' "$SKILLS_FILTER" | tr ',' ' ')"
fi

if [[ "$SKILLS_ONLY" -ne 1 && "$SKIP_AGENTS" -ne 1 ]]; then
  if [[ -e "$TARGET/AGENTS.md" && "$FORCE" -ne 1 ]]; then
    echo "  skip   AGENTS.md (exists — merge missing facts, or use --force)"
    echo "         To merge or refresh it from real repo evidence, run the"
    echo "         generation prompt printed at the end of this script."
  else
    copy_file "$KIT_DIR/templates/AGENTS.template.md" "$TARGET/AGENTS.md"
  fi
fi

# Copy missing files on rerun; --force updates kit files without removing local additions.
[[ "$DRY" -eq 1 ]] || mkdir -p "$TARGET/.agents/skills"
# Splitting the validated skill list is intentional.
# shellcheck disable=SC2206
selected_array=($SELECTED_SKILLS)
for name in "${selected_array[@]}"; do
  name="$(printf '%s' "$name" | tr -d '[:space:]')"
  [[ -n "$name" ]] || continue
  case "$name" in
    *[/.]*)
      echo "error: invalid skill name: $name" >&2
      exit 1
      ;;
  esac
  skill_dir="$KIT_DIR/.agents/skills/$name"
  if [[ ! -d "$skill_dir" ]]; then
    echo "error: unknown skill: $name (see --list-skills)" >&2
    exit 1
  fi
  if [[ -L "$TARGET/.agents/skills/$name" ]]; then
    echo "error: refusing symlink skill directory: $name" >&2
    exit 1
  fi
  while IFS= read -r -d '' source_file; do
    relative_file="${source_file#"$KIT_DIR"/}"
    copy_file "$source_file" "$TARGET/$relative_file"
  done < <(find "$skill_dir" -type f -print0)
done

if [[ "$SKILLS_ONLY" -ne 1 ]]; then
  [[ "$DRY" -eq 1 ]] || mkdir -p "$TARGET/.agents/skills"
  copy_file "$KIT_DIR/.agents/skills/README.md" "$TARGET/.agents/skills/README.md"
  copy_file "$KIT_DIR/scripts/install-hooks.sh" "$TARGET/.agents/install-hooks.sh"
  copy_file "$KIT_DIR/scripts/setup-check.sh" "$TARGET/.agents/setup-check.sh"
  copy_file "$KIT_DIR/templates/hooks/pre-commit" "$TARGET/.agents/hooks/pre-commit"
  for starter in "$KIT_DIR"/templates/verify/*.sh; do
    copy_file "$starter" "$TARGET/.agents/verify-templates/$(basename "$starter")"
  done
fi

if [[ "$WITH_CURSOR" -eq 1 ]]; then
  for rule in "$KIT_DIR"/.cursor/rules/*.mdc; do
    copy_file "$rule" "$TARGET/.cursor/rules/$(basename "$rule")"
  done
fi

if [[ "$WITH_GITHUB" -eq 1 && "$SKILLS_ONLY" -ne 1 ]]; then
  copy_file "$KIT_DIR/templates/github/pull_request_template.md" "$TARGET/.github/pull_request_template.md"
  copy_file "$KIT_DIR/templates/github/workflows/policy.yml" "$TARGET/.github/workflows/policy.yml"
  copy_file "$KIT_DIR/templates/github/workflows/gates.yml" "$TARGET/.github/workflows/gates.yml"
  copy_file "$KIT_DIR/templates/github/scripts/policy-check.sh" "$TARGET/.github/scripts/policy-check.sh"
  copy_file "$KIT_DIR/templates/github/CODEOWNERS.example" "$TARGET/.github/CODEOWNERS.example"
fi

cat <<'NEXT'

Next steps
  1. In the target repo, ask your agent:
         Complete this repository's Agent Engineering Kit setup. Follow
         .agents/skills/full-setup/SKILL.md. Derive unknowns from the repo;
         ask me only for facts or permissions you cannot determine.
  2. Check local readiness with bash .agents/setup-check.sh .
  3. No .agents/verify.sh yet? Copy one starter and edit the SETUP lines:
         .agents/verify-templates/shell.sh | node.sh | python.sh
     Then bash .agents/setup-check.sh . --fix installs the fast commit hook.
  4. Start future sessions with: "Read AGENTS.md and follow it."

Docs: docs/01-agent-workflow.md (the loop), docs/03-verification-gates.md
(gates), docs/04-performance-guards.md (the hard rules), docs/05-adding-a-skill.md,
docs/07-loop-enforcement.md (making juniors unable to skip the loop).
NEXT
