#!/bin/sh
# Runs inside the toolchain container (build.sh). /workerd is the checkout volume, /root/.cache
# the Bazel cache volume, /patches our patches, /out where the binary goes.
#   build-workerd <tag> [bazel args...]
set -eu
TAG=$1
shift

cd /workerd
if [ ! -d .git ]; then
  git init -q .
  git remote add origin https://github.com/cloudflare/workerd.git
fi
git fetch -q --depth 1 origin "refs/tags/$TAG:refs/tags/$TAG"
# Back to the pristine tag: drops the previous patches and local edits, keeps ignored files
# (Bazel's convenience symlinks, node_modules).
git checkout -q -f "refs/tags/$TAG"
git clean -q -fd
for p in /patches/*.patch; do
  echo "applying $p"
  git apply "$p"
done
echo "build:linux --repo_env=CC=/usr/lib/llvm-22/bin/clang" >> .bazelrc

pnpm install --frozen-lockfile
bazel build --config=release_linux "$@" //src/workerd/server:workerd
cp -L bazel-bin/src/workerd/server/workerd /out/workerd
