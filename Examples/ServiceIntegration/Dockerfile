ARG SWIFT_VERSION=6.2
ARG UBI_VERSION=9

FROM docker.apple.com/base-images/ubi${UBI_VERSION}/swift${SWIFT_VERSION}-builder AS builder

WORKDIR /swift-metrics-extras

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Examples/ServiceIntegration/Package.* ./Examples/ServiceIntegration/
COPY ./Package.* ./
RUN swift package --package-path Examples/ServiceIntegration resolve \
        $([ -f ./Examples/ServiceIntegration/Package.resolved ] && echo "--force-resolved-versions" || true)

# Copy the Sources dirs into container
COPY ./Sources ./Sources
COPY ./Examples/ServiceIntegration/Sources ./Examples/ServiceIntegration/Sources

# Build the application, with optimizations
RUN swift build --package-path Examples/ServiceIntegration -c release --product ServiceIntegrationExample

FROM docker.apple.com/base-images/ubi${UBI_VERSION}-minimal/swift${SWIFT_VERSION}-runtime

USER root
RUN mkdir -p /app/bin
COPY --from=builder /swift-metrics-extras/Examples/ServiceIntegration/.build/release/ServiceIntegrationExample /app/bin
RUN mkdir -p /logs && chown $NON_ROOT_USER_ID /logs
USER $NON_ROOT_USER_ID

WORKDIR /app
# If crash log creation times out in a prod environment, consider changing to symbolicate=fast
# For details, check out https://docs.apple.com/documentation/swift-on-server/collecting-crash-logs
ENV SWIFT_BACKTRACE=interactive=no,color=no,output-to=/logs,format=json,symbolicate=full
CMD /app/bin/ServiceIntegrationExample serve
EXPOSE 8080
