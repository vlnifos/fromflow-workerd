#!/bin/sh
# Builds workerd with our patches into ./out/workerd (Linux, for this machine's CPU).
# The arm64 release binary for the sites VPS comes from CI (.github/workflows/build.yml).
#   sh build.sh                         # version from VERSION
#   BAZEL_ARGS="--jobs=4" sh build.sh   # fewer parallel jobs if the machine runs out of memory
#
# The checkout and Bazel's caches live in the named volumes workerd-src and workerd-bazel:
# the first build compiles V8 (over an hour on 8 cores), later builds recompile only what
# changed. A workerd version bump that moves V8 is a full build again.
# `docker volume rm workerd-src workerd-bazel` starts from scratch.
set -eu
cd "$(dirname "$0")"
TAG=$(cat VERSION)
started=$(date +%s)
# Docker on Windows needs a Windows path for bind mounts (Git Bash: pwd -W).
HERE=$(pwd -W 2>/dev/null || pwd)

docker build -q -t workerd-toolchain .
# The exported binary is read-only on some hosts: clear the old one first.
rm -rf out
mkdir -p out
# shellcheck disable=SC2086
MSYS_NO_PATHCONV=1 docker run --rm \
  -v workerd-src:/workerd \
  -v workerd-bazel:/root/.cache \
  -v "$HERE/patches:/patches:ro" \
  -v "$HERE/out:/out" \
  workerd-toolchain build-workerd "$TAG" ${BAZEL_ARGS:-}

echo "workerd $TAG + patches -> out/workerd in $(( $(date +%s) - started )) s"
