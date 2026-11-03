#!/bin/sh
set -eu

go get golang.org/x/net@v0.62.0 golang.org/x/crypto@v0.58.0

test "$(go list -m -f '{{.Version}}' golang.org/x/net)" = "v0.62.0"
test "$(go list -m -f '{{.Version}}' golang.org/x/crypto)" = "v0.58.0"

if go list -deps ./metricbeat | grep -qx 'golang.org/x/crypto/openpgp'; then
  echo 'refusing to suppress GO-2026-5932: openpgp is linked into Metricbeat' >&2
  exit 1
fi
