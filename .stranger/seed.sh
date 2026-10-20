#!/bin/sh
# Places this repository's recorded agent sessions where Claude Code, Codex and Cursor keep their history for
# this clone, so a first run can read them back. Run it from the clone's top folder:
#
#   sh .stranger/seed.sh            place the sessions and write .stranger/manifest
#   sh .stranger/seed.sh --cleanup  delete exactly the files in the manifest (and the folders it made, if empty)
#
# It never overwrites a file and touches nothing else in your home folder. The sessions are synthetic.
set -eu

die() {
  printf 'seed.sh: %s\n' "$1" >&2
  exit 1
}

[ -f .stranger/seed.sh ] || die "run it from the clone's top folder: sh .stranger/seed.sh"
[ -n "${HOME:-}" ] || die "HOME is not set"
manifest=".stranger/manifest"

root=$(pwd -P)
# The path goes into JSON strings and sed replacements: refuse characters that would need escaping there.
case "$root" in
  *[!A-Za-z0-9._/\ -]*) die "this clone's path has characters seed.sh does not handle; clone it under a plain path" ;;
esac
# Yesterday (UTC), so every session lies inside the backfill window and none is in the future.
day=$(date -u -d yesterday +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)
y=${day%%-*}
md=${day#*-}
m=${md%%-*}
d=${md#*-}

claude_dir="$HOME/.claude/projects/$(printf '%s' "$root" | LC_ALL=C sed 's/[^A-Za-z0-9]/-/g')"
cursor_dir="$HOME/.cursor/projects/$(printf '%s' "$root" | LC_ALL=C sed -e 's/[^A-Za-z0-9]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')/agent-transcripts"
codex_root="${CODEX_HOME:-$HOME/.codex}"
codex_dir="$codex_root/sessions/$y/$m/$d"

# Whether a manifest line's path is one seed.sh may have made: a file inside the three session folders, or a folder
# on the way to them. Anything else (an edited manifest, a path with . or .. in it) is left alone.
may_remove() {
  case "$2" in
    */../* | */.. | */./* | */.) return 1 ;;
  esac
  if [ "$1" = f ]; then
    case "$2" in
      "$claude_dir"/* | "$cursor_dir"/* | "$codex_root"/sessions/*) return 0 ;;
    esac
  else
    case "$2" in
      "$HOME"/.claude | "$HOME"/.claude/* | "$HOME"/.cursor | "$HOME"/.cursor/* | "$codex_root" | "$codex_root"/*) return 0 ;;
    esac
  fi
  return 1
}

if [ "${1:-}" = "--cleanup" ]; then
  [ -f "$manifest" ] || die "nothing to clean up (no .stranger/manifest)"
  removed=0
  # Files first, then the folders seed.sh made, deepest first; a folder that is not empty stays.
  while IFS= read -r line; do
    case "$line" in
      "f "*)
        path=${line#f }
        if may_remove f "$path" && [ -f "$path" ] && [ ! -L "$path" ]; then
          rm -f -- "$path"
          removed=$((removed + 1))
        fi
        ;;
    esac
  done <"$manifest"
  sed -n 's/^d //p' "$manifest" | sort -r | while IFS= read -r dir; do
    if may_remove d "$dir" && [ ! -L "$dir" ]; then rmdir -- "$dir" 2>/dev/null || true; fi
  done
  rm -f -- "$manifest"
  printf 'seed.sh: removed %s files\n' "$removed"
  exit 0
fi

[ $# -eq 0 ] || die "usage: sh .stranger/seed.sh [--cleanup]"
[ ! -e "$manifest" ] || die "already seeded; run sh .stranger/seed.sh --cleanup first"

: >"$manifest"

# mkdir -p under $base, recording each folder it makes. The first folder that already exists must be where its name
# says (pwd -P resolves every symbolic link on the way): a linked folder could lead anywhere, so seed.sh stops.
make_dir() {
  if [ -d "$1" ]; then
    case "$1" in
      "$base" | "$base"/*) ;;
      *) return 0 ;;
    esac
    [ "$(cd -- "$1" && pwd -P)" = "$base_p${1#"$base"}" ] ||
      die "$1 is or sits under a symbolic link; nothing was written there (run --cleanup to undo the rest)"
    return 0
  fi
  make_dir "$(dirname -- "$1")"
  mkdir -- "$1"
  printf 'd %s\n' "$1" >>"$manifest"
}

# Copies one session with the placeholders rewritten; refuses to replace anything that exists.
place() {
  src=$1
  dest=$2
  base=$3
  base_p=$(cd -- "$base" 2>/dev/null && pwd -P) || base_p=$base
  { [ ! -e "$dest" ] && [ ! -L "$dest" ]; } || die "$dest exists already; nothing was overwritten (run --cleanup to undo the rest)"
  make_dir "$(dirname -- "$dest")"
  printf 'f %s\n' "$dest" >>"$manifest"
  sed -e "s|__ROOT__|$root|g" -e "s|__DAY__|$day|g" "$src" >"$dest"
}

placed=0
for src in .stranger/sessions/claude-code/*.jsonl; do
  place "$src" "$claude_dir/$(basename -- "$src")" "$HOME"
  placed=$((placed + 1))
done
for src in .stranger/sessions/codex/*.jsonl; do
  name=$(basename -- "$src" | sed "s|__DAY__|$day|g")
  place "$src" "$codex_dir/$name" "$codex_root"
  placed=$((placed + 1))
done
for src in .stranger/sessions/cursor/*.jsonl; do
  id=$(basename -- "$src" .jsonl)
  place "$src" "$cursor_dir/$id/$id.jsonl" "$HOME"
  placed=$((placed + 1))
done
printf 'seed.sh: placed %s sessions (listed in .stranger/manifest)\n' "$placed"
