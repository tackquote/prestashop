#!/usr/bin/env bash
#
# Build the installable PrestaShop artifact, reproducibly: dist/tack-prestashop.zip.
#
# Split out of the hub repository's scripts/package-all.sh
# (https://github.com/tackquote/tack-ecommerce-extensions) when this module moved to
# its own repository, where the module IS the repository root.
#
# "The `name` attribute ... MUST be the same as the module's folder and main
# class file" (Creating your first module). So the zip's top-level directory is
# `tackquotes/` -- whatever this checkout happens to be called. index.php stubs
# are documented and kept; composer.json and the cs-fixer config are build-time
# only (no runtime deps) and are dropped.
#
# Usage: scripts/package.sh [outdir]     (default: dist)

set -Eeuo pipefail

OUT="${1:-dist}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
rm -rf "$OUT" && mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Excluded from every artifact. `-x` patterns are matched by zip against the
# paths as it stores them, so they are relative to the staged tree.
COMMON_EX=( -x '*/.git/*' -x '*/.gitignore' -x '*/.DS_Store' -x '*/__MACOSX/*' -x '*/._*' )

say() { printf '  %s\n' "$*"; }

# export_head <dir> -- extract this repository's committed tree (HEAD) into
# <dir>. Every artifact is staged from git, never from the working tree, so
# local litter (node_modules/, composer.lock, .php-cs-fixer.cache, a non-dist
# outdir from an earlier run, ...) can never reach a zip: only tracked files
# exist to be packed. Uncommitted edits are not packed either -- commit first.
export_head() {
  mkdir -p "$1"
  git -C "$ROOT" archive --format=tar HEAD | tar -x -C "$1"
}

# stage_repo <dest> -- export this repository's committed tree to $STAGE/<dest>,
# minus the repository scaffolding that was never part of the extension when it
# lived in the hub monorepo (this script, the CI workflows, the repo-level
# LICENSE and .gitignore). Keeps the artifact to the same file set the
# monorepo's package-all.sh shipped. git metadata, build output and vendor/ are
# untracked, so the export never contains them.
stage_repo() {
  local d="$STAGE/$1"
  rm -rf "$d"
  export_head "$d"
  rm -rf "$d/scripts" "$d/.github/workflows" "$d/LICENSE" "$d/.gitignore"
  rmdir "$d/.github" 2>/dev/null || true
  find "$d" -name '.DS_Store' -delete 2>/dev/null || true
}

pack() { # pack <zipname> <top-level-dir> [extra zip -x args...]
  local name="$1" top="$2"; shift 2
  ( cd "$STAGE" && zip -q -r -X "$OUT/$name" "$top" "${COMMON_EX[@]}" "$@" )
  say "$name  $(wc -c < "$OUT/$name" | tr -d ' ') bytes"
}

say "prestashop"
stage_repo tackquotes
pack tack-prestashop.zip tackquotes \
  -x 'tackquotes/.github/*' -x 'tackquotes/.php-cs-fixer.dist.php' \
  -x 'tackquotes/composer.json' -x 'tackquotes/composer.lock' \
  -x 'tackquotes/vendor/*' -x 'tackquotes/tests/*' -x 'tackquotes/_dev/*'

echo
echo "artifacts in $OUT:"
ls -1 "$OUT"
