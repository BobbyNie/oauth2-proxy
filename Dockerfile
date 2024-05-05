# This ARG has to be at the top, otherwise the docker daemon does not known what to do with FROM ${RUNTIME_IMAGE}
ARG RUNTIME_IMAGE=registry.access.redhat.com/ubi8/ubi-minimal

# All builds should be done using the platform native to the build node to allow
#  cache sharing of the go mod download step.
# Go cross compilation is also faster than emulation the go compilation across
#  multiple platforms.
FROM registry.access.redhat.com/ubi8/go-toolset AS builder

ENV GOPATH=$APP_ROOT
ENV GOBIN=$APP_ROOT/bin
# Copy sources
WORKDIR $GOPATH/src/github.com/oauth2-proxy

# Fetch dependencies
COPY go.mod go.sum ./
RUN go mod download

# Now pull in our code
COPY . .

# Arguments go here so that the previous steps can be cached if no external
#  sources have changed.
ARG VERSION 

# Build binary and make sure there is at least an empty key file.
#  This is useful for GCP App Engine custom runtime builds, because
#  you cannot use multiline variables in their app.yaml, so you have to
#  build the key into the container and then tell it where it is
#  by setting OAUTH2_PROXY_JWT_KEY_FILE=/etc/ssl/private/jwt_signing_key.pem
#  in app.yaml instead.
# Set the cross compilation arguments based on the TARGETPLATFORM which is
#  automatically set by the docker engine.
RUN make build 
RUN cp $GOPATH/src/github.com/oauth2-proxy/oauth2-proxy /tmp/oauth2-proxy

# Copy binary to runtime image
FROM ${RUNTIME_IMAGE}
COPY --from=builder /tmp/oauth2-proxy /bin/oauth2-proxy
#COPY --from=builder /go/src/github.com/oauth2-proxy/oauth2-proxy/jwt_signing_key.pem /etc/ssl/private/jwt_signing_key.pem

ENTRYPOINT ["/bin/oauth2-proxy"]
