# Metricbeat hardened source build

Metricbeat 9.5.6 rebuilt from the verified `elastic/beats` release commit with a current
Chainguard Go toolchain and a shell-less static runtime. Published as
`mohankrishna999/metricbeat:9.5.6.1-patched` for amd64 and arm64. 9.5.6 is the newest
Elastic 9 release.

`9.5.6.1-patched` raises `golang.org/x/crypto` from 0.58.0 to
`v0.58.1-0.20261009181718-2f1f834330b2`, the upstream fix for GO-2026-5932 (no tagged
release yet), with `golang.org/x/net` 0.62.0 as before (`build/patch-modules.sh`). The
build fails if either pin does not apply, or if `golang.org/x/crypto/openpgp` is linked in.

The image preserves the standard `/usr/share/metricbeat` layout and runs as UID 1000,
primary GID 0. Kubernetes and OpenShift manifests use read-only host mounts for `/proc`
and `/sys`, a read-only root filesystem, and no added Linux capabilities.
