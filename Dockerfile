# GitHub Actions Runner - Podman Image
# Enterprise-grade, minimal container image for self-hosted GitHub Actions runners
# Based on Red Hat Universal Base Image 9 Minimal (UBI 9)

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

LABEL maintainer="Infrastructure Team"
LABEL description="GitHub Actions self-hosted runner with Podman support - UBI 9 based"
LABEL version="1.0.0"
LABEL base_image="ubi9"

# Set environment variables
ENV RUNNER_ALLOW_RUNASROOT=false \
    RUNNER_UID=1001 \
    RUNNER_GID=1001 \
    RUNNER_HOME=/home/runner \
    PATH="/opt/runner/bin:${PATH}"

# Install base packages and dependencies using microdnf (UBI minimal)
RUN microdnf install -y \
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
    make \
    which \
    # Shell utilities
    bash \
    # VCS and utilities
    openssh-clients \
    openssh-server \
    openssh-keygen \
    # Container tools (Podman)
    podman \
    skopeo \
    buildah \
    # Build essentials
    gcc \
    gcc-c++ \
    make \
    pkg-config \
    # Programming languages
    python3 \
    python3-pip \
    python3-devel \
    # Node.js for common workflows
    nodejs \
    npm \
    # System utilities
    sudo \
    dbus \
    # Additional utils
    sshpass \
    rsync \
    vim-minimal \
    # Cleanup
    && microdnf clean all \
    && rm -rf /var/cache/dnf/* \
    && rm -rf /tmp/*

# Create runner user with home directory
RUN groupadd -g ${RUNNER_GID} runner && \
    useradd -m -u ${RUNNER_UID} -g ${RUNNER_GID} -s /bin/bash runner && \
    usermod -aG wheel runner && \
    echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/runner && \
    chmod 0440 /etc/sudoers.d/runner && \
    mkdir -p ${RUNNER_HOME}/.config/containers && \
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
    ./bin/installdependencies.sh && \
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

