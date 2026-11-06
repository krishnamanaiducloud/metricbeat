# Metricbeat hardened source build

Metricbeat 8.19.24 rebuilt from the verified `elastic/beats` release commit with a current
Chainguard Go toolchain and a shell-less static runtime. Published as
`mohankrishna999/metricbeat:8.19.24-patched` for amd64 and arm64.

The image preserves the standard `/usr/share/metricbeat` layout and runs as UID 1000,
primary GID 0. Kubernetes and OpenShift manifests use read-only host mounts for `/proc`
and `/sys`, a read-only root filesystem, and no added Linux capabilities.
