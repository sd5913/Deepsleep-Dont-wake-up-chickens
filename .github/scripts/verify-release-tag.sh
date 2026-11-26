#!/usr/bin/env bash
set -euo pipefail

tag="$1"
pushed_sha="$2"
number='(0|[1-9][0-9]*)'
if [[ ! "$tag" =~ ^v$number\.$number\.$number$ ]]; then
  echo 'A release tag must look like v1.2.3, with no leading zeroes or suffixes.' >&2
  exit 1
fi

ref="refs/tags/$tag"
if ! tag_object="$(git rev-parse --verify --quiet "$ref")"; then
  echo "Tag $tag does not exist." >&2
  exit 1
fi
if ! tag_commit="$(git rev-parse --verify --quiet "$ref^{commit}")"; then
  echo "Tag $tag does not point to a commit." >&2
  exit 1
fi
# A lightweight tag is a commit ID. An annotated tag has a separate object ID.
if [[ "$pushed_sha" != "$tag_object" && "$pushed_sha" != "$tag_commit" ]]; then
  echo "Tag $tag does not match the pushed revision." >&2
  exit 1
fi
if ! git merge-base --is-ancestor "$tag_commit" refs/remotes/origin/main; then
  echo "Tag $tag points to $tag_commit, which is not reachable from main." >&2
  exit 1
fi

printf '%s\n' "$tag_object"
