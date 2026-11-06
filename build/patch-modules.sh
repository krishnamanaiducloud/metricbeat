#!/bin/sh
set -eu

# golang.org/x/crypto is pinned to the upstream fix commit for GO-2026-5932 (no tagged release yet).
pins="golang.org/x/net@v0.62.0 golang.org/x/crypto@v0.58.1-0.20261009181718-2f1f834330b2"

# shellcheck disable=SC2086
go get $pins

for pin in $pins; do
  test "$(go list -m -f '{{.Version}}' "${pin%@*}")" = "${pin#*@}"
done
