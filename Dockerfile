# Toolchain for building workerd the way upstream does (Dockerfile.release and the devcontainer
# in cloudflare/workerd): Debian trixie, LLVM 22, Bazel via bazelisk, pnpm.
#
# Only the tools live in the image. The checkout and the Bazel caches live in named volumes
# (build.sh), so a rebuild after a patch change recompiles only what changed. BuildKit cache
# mounts were tried first and lost the cache between builds.
FROM node:trixie

# LLVM 22 from apt.llvm.org. Upstream runs llvm.sh, which needs software-properties-common —
# gone from trixie — so the repository is added by hand.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl dpkg-dev git gnupg lsb-release wget \
    && wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor -o /usr/share/keyrings/llvm.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/llvm.gpg] http://apt.llvm.org/trixie/ llvm-toolchain-trixie-22 main" \
      > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends clang-22 lld-22 libunwind-22-dev libc++-22-dev libclang-rt-22-dev \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pnpm@latest @bazel/bazelisk

COPY --chmod=755 build-in-container.sh /usr/local/bin/build-workerd
WORKDIR /workerd
