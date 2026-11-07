#!/bin/sh
set -eu

# golang.org/x/crypto has no tagged release with the GO-2026-5932 fix yet; this is the upstream fix commit.
go get golang.org/x/net@v0.62.0 golang.org/x/crypto@v0.58.1-0.20261009181718-2f1f834330b2

test "$(go list -m -f '{{.Version}}' golang.org/x/net)" = "v0.62.0"
test "$(go list -m -f '{{.Version}}' golang.org/x/crypto)" = "v0.58.1-0.20261009181718-2f1f834330b2"

if go list -deps ./metricbeat | grep -qx 'golang.org/x/crypto/openpgp'; then
  echo 'golang.org/x/crypto/openpgp is linked into Metricbeat' >&2
  exit 1
fi
