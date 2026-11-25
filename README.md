# Metricbeat hardened source build

Metricbeat 8.19.19 rebuilt from the verified `elastic/beats` release commit with a current
Chainguard Go toolchain and a shell-less static runtime. Published as
`mohankrishna999/metricbeat:8.19.19.3-patched` for amd64 and arm64.

## 8.19.19.3-patched

- **Same distribution as the official image.** The binary is now built from
  `x-pack/metricbeat`, the default distribution in `docker.elastic.co/beats/metricbeat`.
  The previous tag was built from the OSS `metricbeat` package and lacked 25 modules (among
  them aws, azure, gcp, sql, mssql, oracle, statsd, tomcat, containerd, coredns and istio)
  and the Kibana dashboards.
- **Same data files.** The image now carries the official 8.19.19 image's data files, unchanged
  and pinned by digest: light modules, `modules.d`, the Kibana dashboards for `setup
  --dashboards`, `fields.yml`, `metricbeat.reference.yml` and the default
  `metricbeat.yml`. No binary comes from the official image.
- **No test files in the image.** The previous tag copied the source `module/` tree, which
  includes test Dockerfiles, a test `pom.xml` and an EKS Terraform `requirements.txt`.
  That requirements file is where scanners found `urllib3` and `pyasn1`.
- **Updated modules.** `kernel.org/pub/linux/libs/security/libcap/cap` and `psx` are
  raised from v1.2.57 to v1.2.78, alongside the existing pins: golang.org/x/net 0.62.0, `golang.org/x/crypto` with the GO-2026-5932 fix (`v0.58.1-0.20261009181718-2f1f834330b2`), golang.org/x/text 0.43.0, google.golang.org/grpc 1.84.0 and github.com/klauspost/compress 1.20.3. See
  `build/patch-modules.sh`; the build fails if a pin does not apply or if
  `golang.org/x/crypto/openpgp` is linked in.
- **OpenTelemetry and Go runtime.** OpenTelemetry-Go is raised to v1.47.0 and the
  Chainguard Go toolchain is raised to Go 1.27.4, fixing the reported OTel trace and
  Go standard-library vulnerabilities.
- **Version output.** `metricbeat version` reports the release commit and its time, as
  the official build does (the previous tag printed `unknown`).
- **Same environment.** The image sets `PATH` and
  `LIBBEAT_MONITORING_CGROUPS_HIERARCHY_OVERRIDE=/` as the official image does.

### Oracle module

The static build has no cgo, so the Oracle driver's cgo binding cannot be compiled.
`build/godror-shim.go` stands in for it:
- DSN parsing still uses the real `godror/dsn` package, so the `oracle` and `sql`
  modules load and validate their configuration as before.
- Connecting to Oracle returns `cannot connect to Oracle: this static Metricbeat build
  has no Oracle client library`.

The official image fails the same way (`DPI-1047: Cannot locate a 64-bit Oracle Client
library`) unless Oracle Instant Client is added to it.

### Verification

Compared with `docker.elastic.co/beats/metricbeat:8.19.19`:
- **Static checks:** the same version line, `test config`, the same module list,
  identical `export template` and `export ilm-policy` output, and the same packaged data
  files.
- **Module runs:** the same metricsets and results for system, activemq and tomcat
  (light modules), sql (mysql driver) and mssql.
- **Scans:** Trivy 0.76.2 and Grype 0.121.1 report no findings.

The image preserves the standard `/usr/share/metricbeat` layout and runs as UID 1000,
primary GID 0. Kubernetes and OpenShift manifests use read-only host mounts for `/proc`
and `/sys`, a read-only root filesystem, and no added Linux capabilities.
