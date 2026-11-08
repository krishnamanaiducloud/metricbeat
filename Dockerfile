# syntax=docker/dockerfile:1.7
ARG GO_IMAGE=cgr.dev/chainguard/go:latest-dev@sha256:ed70318f7b4f2e4a82e1dbc363f7a13be3a5805081f86ed9d1ec02d2694c222f
ARG RUNTIME_IMAGE=cgr.dev/chainguard/static:latest@sha256:fc42af33e643f20d08baf03cddcc1c02ba57052dfb02edb0d79f3fc47bcea8d9
# The official image of the same release supplies the packaged data files only: light modules,
# modules.d, Kibana dashboards, fields.yml and the configuration files. No binary is taken from it.
ARG OFFICIAL_IMAGE=docker.elastic.co/beats/metricbeat:8.19.19@sha256:2dcbd24a226a44bb0b734cd91d633437b6abaa56985a5ba46e605de627804294

FROM --platform=$BUILDPLATFORM ${OFFICIAL_IMAGE} AS official

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS source
ARG BEATS_VERSION=8.19.19
ARG BEATS_COMMIT=07e825c0cf248b728a2d3272f47198046d6bb072
USER root
WORKDIR /src
ADD --checksum=sha256:831258ee81b84e40c7bfc00ee9b7d967f6ae77e7cda712ec16ddbb2324dffdb0 \
    https://codeload.github.com/elastic/beats/tar.gz/07e825c0cf248b728a2d3272f47198046d6bb072 /tmp/beats.tar.gz
RUN tar -xzf /tmp/beats.tar.gz --strip-components=1 \
    && rm -f /tmp/beats.tar.gz

FROM source AS patched
COPY build/patch-modules.sh /usr/local/bin/patch-modules.sh
COPY build/godror-shim.go /usr/local/share/godror-shim.go
RUN --mount=type=cache,id=metricbeat-go-mod,target=/root/go/pkg/mod,sharing=locked \
    sh /usr/local/bin/patch-modules.sh

FROM patched AS build
ARG TARGETOS
ARG TARGETARCH
ARG BEATS_COMMIT=07e825c0cf248b728a2d3272f47198046d6bb072
ARG BEATS_COMMIT_TIME=2026-07-15T11:53:13Z
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOEXPERIMENT=nodwarf5
COPY build/buildstamp.go /src/libbeat/version/buildstamp.go
# x-pack/metricbeat is the default distribution that the official image ships. `metricbeat version`
# reports the release commit and its time, as the official build does.
RUN --mount=type=cache,id=metricbeat-go-mod,target=/root/go/pkg/mod,sharing=locked \
    --mount=type=cache,id=metricbeat-go-build,target=/root/.cache/go-build,sharing=locked \
    GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" go build -trimpath -buildvcs=false \
      -ldflags "-s -w -buildid= -X github.com/elastic/beats/v7/libbeat/version.vcsRevision=${BEATS_COMMIT} -X github.com/elastic/beats/v7/libbeat/version.buildVCSTime=${BEATS_COMMIT_TIME}" \
      -o /out/metricbeat ./x-pack/metricbeat \
    && mkdir -p /out/data /out/logs \
    && chown -R 1000:0 /out/data /out/logs \
    && chmod 0770 /out/data /out/logs

FROM ${RUNTIME_IMAGE}
ARG BEATS_VERSION=8.19.19
ARG IMAGE_VERSION=8.19.19.1-patched
LABEL org.opencontainers.image.title="Metricbeat" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.source="https://github.com/elastic/beats" \
      org.opencontainers.image.licenses="Elastic-2.0"
ENV PATH=/usr/share/metricbeat:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    ELASTIC_CONTAINER=true GODEBUG=madvdontneed=1 LIBBEAT_MONITORING_CGROUPS_HIERARCHY_OVERRIDE=/
WORKDIR /usr/share/metricbeat
COPY --from=official --chown=1000:0 /usr/share/metricbeat/LICENSE.txt /usr/share/metricbeat/NOTICE.txt /usr/share/metricbeat/README.md /usr/share/metricbeat/.build_hash.txt /usr/share/metricbeat/fields.yml /usr/share/metricbeat/metricbeat.reference.yml /usr/share/metricbeat/
COPY --from=official --chown=1000:0 /usr/share/metricbeat/kibana /usr/share/metricbeat/kibana
COPY --from=official --chown=1000:0 /usr/share/metricbeat/module /usr/share/metricbeat/module
COPY --from=official --chown=1000:0 /usr/share/metricbeat/modules.d /usr/share/metricbeat/modules.d
COPY --from=official --chown=1000:0 --chmod=0440 /usr/share/metricbeat/metricbeat.yml /usr/share/metricbeat/metricbeat.yml
COPY --from=build --chown=1000:0 --chmod=0555 /out/metricbeat /usr/share/metricbeat/metricbeat
COPY --from=build --chown=1000:0 --chmod=0770 /out/data /usr/share/metricbeat/data
COPY --from=build --chown=1000:0 --chmod=0770 /out/logs /usr/share/metricbeat/logs
USER 1000:0
ENTRYPOINT ["/usr/share/metricbeat/metricbeat"]
CMD ["-e", "--strict.perms=false"]
