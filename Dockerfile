# syntax=docker/dockerfile:1.7
ARG GO_IMAGE=cgr.dev/chainguard/go:latest-dev@sha256:7ec5088173068ac9c376210b7f5fd0de5bcb57c60b508ee867d5e7edf872922b
ARG RUNTIME_IMAGE=cgr.dev/chainguard/static:latest@sha256:fc42af33e643f20d08baf03cddcc1c02ba57052dfb02edb0d79f3fc47bcea8d9

FROM --platform=$BUILDPLATFORM ${GO_IMAGE} AS source
ARG BEATS_VERSION=8.19.24
ARG BEATS_COMMIT=8511bd8ba1e66bc536451a3badf85d02f7588fb4
USER root
WORKDIR /src
ADD --checksum=sha256:3140b154ede2afc8bcc3a7c3e6913834a1c565ad71f2d931e50ca91579f2b7b4 \
    https://codeload.github.com/elastic/beats/tar.gz/8511bd8ba1e66bc536451a3badf85d02f7588fb4 /tmp/beats.tar.gz
RUN tar -xzf /tmp/beats.tar.gz --strip-components=1 \
    && rm -f /tmp/beats.tar.gz

FROM source AS patched
COPY build/patch-modules.sh /usr/local/bin/patch-modules.sh
RUN --mount=type=cache,id=metricbeat-go-mod,target=/root/go/pkg/mod,sharing=locked \
    sh /usr/local/bin/patch-modules.sh

FROM patched AS build
ARG TARGETOS
ARG TARGETARCH
ARG BEATS_COMMIT=8511bd8ba1e66bc536451a3badf85d02f7588fb4
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOEXPERIMENT=nodwarf5
RUN --mount=type=cache,id=metricbeat-go-mod,target=/root/go/pkg/mod,sharing=locked \
    --mount=type=cache,id=metricbeat-go-build,target=/root/.cache/go-build,sharing=locked \
    GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" go build -trimpath -buildvcs=false \
      -ldflags "-s -w -buildid= -X github.com/elastic/beats/v7/libbeat/version.buildTime=unknown -X github.com/elastic/beats/v7/libbeat/version.commit=${BEATS_COMMIT}" \
      -o /out/metricbeat ./metricbeat \
    && mkdir -p /out/data /out/logs \
    && chown -R 1000:0 /out/data /out/logs \
    && chmod 0770 /out/data /out/logs

FROM ${RUNTIME_IMAGE}
ARG BEATS_VERSION=8.19.24
LABEL org.opencontainers.image.title="Metricbeat" \
      org.opencontainers.image.version="${BEATS_VERSION}-patched" \
      org.opencontainers.image.source="https://github.com/elastic/beats" \
      org.opencontainers.image.licenses="Elastic-2.0"
ENV ELASTIC_CONTAINER=true GODEBUG=madvdontneed=1
WORKDIR /usr/share/metricbeat
COPY --from=build --chown=1000:0 --chmod=0555 /out/metricbeat /usr/share/metricbeat/metricbeat
COPY --from=build --chown=1000:0 --chmod=0440 /src/metricbeat/metricbeat.yml /usr/share/metricbeat/metricbeat.yml
COPY --from=build --chown=1000:0 /src/metricbeat/modules.d /usr/share/metricbeat/modules.d
COPY --from=build --chown=1000:0 /src/metricbeat/module /usr/share/metricbeat/module
COPY --from=build --chown=1000:0 --chmod=0770 /out/data /usr/share/metricbeat/data
COPY --from=build --chown=1000:0 --chmod=0770 /out/logs /usr/share/metricbeat/logs
USER 1000:0
ENTRYPOINT ["/usr/share/metricbeat/metricbeat"]
CMD ["-e", "--strict.perms=false"]
