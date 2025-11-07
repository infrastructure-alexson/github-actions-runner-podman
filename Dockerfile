# GitHub Actions Runner - Podman Support
# Production-ready container image for self-hosted GitHub Actions runners
# Based on Ubuntu 22.04 LTS (officially recommended base for GitHub Actions)
# 
# Includes: Podman (with docker compatibility), Buildah, Skopeo for container image building
# Uses Ubuntu 22.04 LTS for broad compatibility and being the official GitHub Actions base
# Ubuntu is widely tested and most compatible with GitHub runner environment

FROM ubuntu:22.04

LABEL maintainer="Infrastructure Team"
LABEL description="GitHub Actions self-hosted runner with Podman support (docker compatible) - Ubuntu 22.04 based"
LABEL version="1.3.0"
LABEL base_image="ubuntu2204"
LABEL container_tools="podman,podman-docker,buildah,skopeo"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_ALLOW_RUNASROOT=false \
    RUNNER_UID=1001 \
    RUNNER_GID=1001 \
    RUNNER_HOME=/home/runner \
    PATH="/opt/runner/bin:${PATH}"

# Install base packages and dependencies using apt (Ubuntu 22.04)
# apt is the package manager in Ubuntu
# Ubuntu 22.04 is x86-64-v1 compatible - includes baseline 64-bit x86 instructions
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential tools
    curl \
    wget \
    ca-certificates \
    git \
    git-lfs \
    jq \
    unzip \
    tar \
    gzip \
    # Shell utilities
    bash \
    locales \
    # VCS and utilities
    openssh-client \
    openssh-server \
    # Container tools (Podman - via containers.io repo)
    podman \
    skopeo \
    buildah \
    # Build essentials
    gcc \
    g++ \
    make \
    pkg-config \
    # Programming languages
    python3 \
    python3-pip \
    python3-venv \
    # Node.js for common workflows
    nodejs \
    npm \
    # System utilities
    sudo \
    dbus \
    hostname \
    findutils \
    procps \
    # .NET Core dependencies (GitHub Actions Runner requirements)
    libicu70 \
    libssl3 \
    libkrb5-3 \
    # Additional utils
    sshpass \
    rsync \
    vim-tiny \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Add containers.io repository for podman-docker and other container tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository -y ppa:containers/stable \
    && apt-get update && apt-get install -y --no-install-recommends \
    podman-docker \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create runner user with home directory
RUN groupadd -g ${RUNNER_GID} runner && \
    useradd -m -u ${RUNNER_UID} -g ${RUNNER_GID} -s /bin/bash runner && \
    usermod -aG sudo runner && \
    # Add runner to podman group for rootless container support
    getent group podman >/dev/null && usermod -aG podman runner || true && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/runner && \
    chmod 0440 /etc/sudoers.d/runner && \
    # Setup container config directories
    mkdir -p ${RUNNER_HOME}/.config/containers && \
    mkdir -p ${RUNNER_HOME}/.kube && \
    chown -R runner:runner ${RUNNER_HOME}

# Download and setup GitHub Actions Runner
RUN mkdir -p /opt/runner && \
    cd /opt/runner && \
    RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//') && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH_SUFFIX="x64"; else ARCH_SUFFIX="arm64"; fi && \
    echo "Downloading GitHub Actions Runner v${RUNNER_VERSION} for ${ARCH}..." && \
    curl -L -O "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH_SUFFIX}-${RUNNER_VERSION}.tar.gz" && \
    tar xzf "actions-runner-linux-${ARCH_SUFFIX}-${RUNNER_VERSION}.tar.gz" && \
    rm "actions-runner-linux-${ARCH_SUFFIX}-${RUNNER_VERSION}.tar.gz" && \
    # Note: Skip installdependencies.sh as UBI Minimal uses microdnf not yum
    # All required .NET Core dependencies were already installed above
    echo "Runner binaries extracted. .NET Core dependencies pre-installed via microdnf." && \
    chown -R runner:runner /opt/runner

# Copy entrypoint script
COPY --chown=runner:runner ./scripts/entrypoint.sh /opt/runner/entrypoint.sh
RUN chmod +x /opt/runner/entrypoint.sh

# Configure Podman for rootless operation
RUN mkdir -p ${RUNNER_HOME}/.config/containers && \
    echo "cgroup_manager = \"cgroupfs\"" >> ${RUNNER_HOME}/.config/containers/containers.conf && \
    echo "runtime = \"runc\"" >> ${RUNNER_HOME}/.config/containers/containers.conf && \
    chown -R runner:runner ${RUNNER_HOME}/.config

# Set working directory
WORKDIR ${RUNNER_HOME}

# Switch to runner user
USER runner

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD test -f ${RUNNER_HOME}/.configured || exit 1

# Set entrypoint
ENTRYPOINT ["/opt/runner/entrypoint.sh"]

# Default command
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]

