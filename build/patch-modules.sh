#!/bin/sh
set -eu
export CGO_ENABLED=0

# golang.org/x/crypto has no tagged release with the GO-2026-5932 fix yet; this is the upstream fix commit.
# libcap cap/psx v1.2.78 (libcap 2.78) replace upstream's v1.2.57.
# OpenTelemetry-Go v1.47.0 fixes CVE-2026-128085 in the trace package.
pins="golang.org/x/net@v0.62.0 golang.org/x/crypto@v0.58.1-0.20261009181718-2f1f834330b2 golang.org/x/text@v0.43.0 google.golang.org/grpc@v1.84.0 github.com/klauspost/compress@v1.20.3 go.opentelemetry.io/otel@v1.47.0 go.opentelemetry.io/otel/trace@v1.47.0 kernel.org/pub/linux/libs/security/libcap/cap@v1.2.78 kernel.org/pub/linux/libs/security/libcap/psx@v1.2.78"

# shellcheck disable=SC2086
go get $pins

for pin in $pins; do
  test "$(go list -m -f '{{.Version}}' "${pin%@*}")" = "${pin#*@}"
done

# The default distribution (x-pack/metricbeat) links the Oracle driver github.com/godror/godror, a cgo
# binding to ODPI-C. This static build replaces its root package with godror-shim.go: the real godror/dsn
# package still parses DSNs, and connecting reports that no Oracle client library is available.
go mod download github.com/godror/godror
godror_src=$(go list -m -f '{{.Dir}}' github.com/godror/godror)
rm -rf third_party/godror
mkdir -p third_party
cp -R "$godror_src" third_party/godror
chmod -R u+w third_party/godror
rm -f third_party/godror/*.go
cp /usr/local/share/godror-shim.go third_party/godror/godror.go
go mod edit -replace github.com/godror/godror=./third_party/godror
test "$(go list -m -f '{{.Replace.Path}}' github.com/godror/godror)" = "./third_party/godror"

if go list -deps ./x-pack/metricbeat | grep -qx 'golang.org/x/crypto/openpgp'; then
  echo 'golang.org/x/crypto/openpgp is linked into Metricbeat' >&2
  exit 1
fi
