#!/usr/bin/env bash

pushd "$(dirname "$0")"
  ln -sf \
    "$(git rev-parse --show-toplevel)"/scripts/rubocop-pre-commit \
    "$(git rev-parse --git-dir)"/hooks/pre-commit
popd
