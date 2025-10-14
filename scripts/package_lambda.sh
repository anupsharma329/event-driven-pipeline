#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_DIR="$ROOT_DIR/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cp -r "$ROOT_DIR/lambda_fn" "$BUILD_DIR/"
pushd "$BUILD_DIR" >/dev/null
python3 -m venv .venv || true
. .venv/bin/activate
pip install -r "$ROOT_DIR/requirements.txt"
deactivate
zip -r processor.zip lambda_fn
popd >/dev/null
echo "Created $BUILD_DIR/processor.zip"
