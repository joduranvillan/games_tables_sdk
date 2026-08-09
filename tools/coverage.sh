#!/usr/bin/env bash
set -euo pipefail

# Run cargo llvm-cov to generate lcov report
cargo llvm-cov --workspace --lcov --output-path coverage/lcov.info

# Generate HTML report from lcov.info using genhtml
genhtml coverage/lcov.info -o coverage/html
