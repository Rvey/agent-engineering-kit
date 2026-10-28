#!/usr/bin/env bash
# install.sh — run the Agent Engineering Kit bootstrap without cloning the kit.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Rvey/agent-engineering-kit/main/scripts/install.sh) [bootstrap options]
#
# Downloads the kit tarball into a temporary directory, runs
# scripts/bootstrap.sh from it with every argument passed through, then
# deletes the download. No arguments in a terminal opens the bootstrap menu.
# Relative targets such as . resolve against the directory you run it from.
#
# Environment:
#   AGENT_KIT_REF      branch, tag, or commit to download (default: main).
#                      Pin a tag or commit for reproducible installs.
#   AGENT_KIT_REPO     GitHub owner/name (default: Rvey/agent-engineering-kit).
#   AGENT_KIT_SHA256   expected SHA-256 of the tarball; a mismatch aborts.
#   AGENT_KIT_TARBALL  local .tar.gz to use instead of downloading (offline/tests).
set -euo pipefail

# Everything runs inside main, called on the last line, so a truncated
# download cannot execute a partial script.
main() {
  local repo="${AGENT_KIT_REPO:-Rvey/agent-engineering-kit}"
  local ref="${AGENT_KIT_REF:-main}"
  local tmp archive actual candidate
  local found=()

  if [[ ! "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    echo "error: invalid AGENT_KIT_REPO: $repo (expected owner/name)" >&2
    exit 1
  fi
  if [[ ! "$ref" =~ ^[A-Za-z0-9._/-]+$ || "$ref" == *..* ]]; then
    echo "error: invalid AGENT_KIT_REF: $ref" >&2
    exit 1
  fi
  command -v tar >/dev/null 2>&1 || { echo "error: tar is required" >&2; exit 1; }

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/agent-kit.XXXXXX")"
  # Expand now: tmp is local to main and gone by the time the EXIT trap fires.
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" EXIT
  archive="$tmp/kit.tar.gz"

  if [[ -n "${AGENT_KIT_TARBALL:-}" ]]; then
    if [[ ! -f "$AGENT_KIT_TARBALL" ]]; then
      echo "error: AGENT_KIT_TARBALL is not a file: $AGENT_KIT_TARBALL" >&2
      exit 1
    fi
    cp "$AGENT_KIT_TARBALL" "$archive"
  else
    command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }
    echo "Downloading $repo@$ref" >&2
    if ! curl -fsSL --proto '=https' --tlsv1.2 -o "$archive" \
      "https://codeload.github.com/$repo/tar.gz/$ref"; then
      echo "error: download failed for $repo@$ref" >&2
      exit 1
    fi
  fi

  if [[ -n "${AGENT_KIT_SHA256:-}" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual="$(sha256sum "$archive" | cut -d' ' -f1)"
    elif command -v shasum >/dev/null 2>&1; then
      actual="$(shasum -a 256 "$archive" | cut -d' ' -f1)"
    else
      echo "error: AGENT_KIT_SHA256 is set but neither sha256sum nor shasum is available" >&2
      exit 1
    fi
    if [[ "$actual" != "$AGENT_KIT_SHA256" ]]; then
      echo "error: checksum mismatch (expected $AGENT_KIT_SHA256, got $actual)" >&2
      exit 1
    fi
  fi

  mkdir "$tmp/src"
  if ! tar -xzf "$archive" -C "$tmp/src"; then
    echo "error: could not unpack the kit tarball" >&2
    exit 1
  fi
  # The tarball holds one top-level directory whose name depends on the ref.
  for candidate in "$tmp"/src/*/scripts/bootstrap.sh; do
    [[ -f "$candidate" && ! -L "$candidate" ]] && found+=("$candidate")
  done
  if [[ "${#found[@]}" -ne 1 ]]; then
    echo "error: tarball does not look like the kit (expected one */scripts/bootstrap.sh)" >&2
    exit 1
  fi

  bash "${found[0]}" "$@"
}

main "$@"
