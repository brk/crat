#!/usr/bin/env bash

set -euxo pipefail

SCRIPTDIR=$(dirname $(realpath "$0"))
OUTDIR="$SCRIPTDIR/out"
BUILD_COMMIT="${1:-}"

if [[ -z "$BUILD_COMMIT" ]]; then
  echo "usage: $0 <commit-hash>" >&2
  exit 1
fi

source "$SCRIPTDIR/common-vars.sh"

docker_env=(
  -e HOST_UID="$(id -u)"
  -e HOST_GID="$(id -g)"
  -e BUILD_COMMIT="$BUILD_COMMIT"
)

if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
  docker_env+=(-e SOURCE_DATE_EPOCH)
fi

docker run --rm -i \
            "${docker_env[@]}" \
            -v "$SCRIPTDIR:/inputs" \
            -v "$OUTDIR:/outputs" \
            --network=host \
                     "$IMAGENAME" sh -s <<'EOF'
  set -eux
  mkdir /tmp/work
  cd /tmp/work

  apt-get update && apt-get install --no-install-recommends libz3-dev libclang-dev -y

  git clone https://github.com/Aarno-Labs/crat.git
  cd crat
  git switch --detach "$BUILD_COMMIT"

  cargo build --manifest-path deps_crate/Cargo.toml
  cargo build --release

  mkdir -p /outputs/bin
  cp ./target/release/crat   /outputs/bin
  cp ./target/release/crat-* /outputs/bin
  mkdir -p /outputs/lib
  zzz=$(find /usr/local/rustup -name librustc_driver-e4d0d5450005c30a.so | head -n1)
  cp "$zzz" /outputs/lib
  zzz=$(find /usr/local/rustup -name libLLVM.so.20.1-rust-1.89.0-nightly | head -n1)
  cp "$zzz" /outputs/lib
  chown -R "$HOST_UID:$HOST_GID" /outputs
EOF
