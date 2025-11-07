# Multi-stage build for GitHub Action Runner
# Supports: Linux amd64, arm64
# Base: Rocky Linux 8

FROM rockylinux:8 AS base

LABEL maintainer="Steven Alexson <stevenalexson@example.com>"
LABEL description="GitHub Action Runner - Podman/Docker compatible"
LABEL version="1.0.0"

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    RUNNER_ALLOW_RUNASROOT=true \
    PATH="/opt/runner:${PATH}"

# Install base dependencies
RUN dnf update -y && \
    dnf install -y \
    # Core tools
    curl \
    wget \
    git \
    jq \
    unzip \
    tar \
    gzip \
    openssh-client \
    openssh-server \
    # Build tools
    gcc \
    make \
    pkg-config \
    # Development
    python3 \
    python3-pip \
    python3-devel \
    # Container tools
    podman \
    docker \
    # Utilities
    ca-certificates \
    which \
    && dnf clean all

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/rpm/gh-cli.repo | \
    tee /etc/yum.repos.d/gh-cli.repo && \
    dnf install -y gh && \
    dnf clean all

# Install GitHub Actions Runner
RUN mkdir -p /opt/runner && \
    cd /opt/runner && \
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//') && \
    echo "Installing GitHub Actions Runner v${RUNNER_VERSION}" && \
    curl -O -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-$(uname -m | sed 's/x86_64/x64/' | sed 's/aarch64/arm64/')-${RUNNER_VERSION}.tar.gz" && \
    tar xzf "actions-runner-linux-"*.tar.gz && \
    rm -f "actions-runner-linux-"*.tar.gz && \
    chmod +x bin/runsvc.sh

# Create runner user
RUN groupadd -g 1000 runner && \
    useradd -m -u 1000 -g runner -d /home/runner -s /bin/bash runner && \
    mkdir -p /home/runner/_work && \
    chown -R runner:runner /home/runner /opt/runner

# Add health check script
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Add entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /opt/runner

# Set user
USER runner

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["--help"]
