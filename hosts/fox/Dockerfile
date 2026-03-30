FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV container=docker

# --- Systemd setup ---
RUN apt-get update && apt-get install -y \
    systemd systemd-sysv dbus \
    openssh-server \
    docker.io \
    curl git sudo \
    iptables iproute2 \
    ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/* \
    # Remove unnecessary systemd units, but keep systemd-user-sessions
    # (it removes /run/nologin which blocks SSH login)
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
    && rm -f /etc/systemd/system/*.wants/* \
    && rm -f /lib/systemd/system/local-fs.target.wants/* \
    && rm -f /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -f /lib/systemd/system/basic.target.wants/* \
    && systemctl enable systemd-user-sessions.service

# --- User setup ---
RUN useradd -m -s /bin/bash -G sudo,docker iorlas \
    && echo "iorlas ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/iorlas \
    && chmod 440 /etc/sudoers.d/iorlas

# --- Defaults for first-boot seeding (staged in /etc/fox-defaults/) ---
COPY hosts/fox/defaults/bashrc /etc/fox-defaults/.bashrc
RUN mkdir -p /etc/fox-defaults/.ssh \
    && curl -fsSL https://github.com/iorlas.keys > /etc/fox-defaults/.ssh/authorized_keys \
    && chmod 600 /etc/fox-defaults/.ssh/authorized_keys

# --- Systemd services ---
COPY hosts/fox/systemd/fox-ssh-keys.service /etc/systemd/system/
RUN systemctl enable fox-ssh-keys.service

# --- Disable password auth ---
RUN sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# --- Install Nix (multi-user, --init none for Docker build without systemd) ---
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --no-confirm --init none

# Helper: runs a command with nix-daemon in background (needed during build)
COPY hosts/fox/defaults/with-nix-daemon /usr/local/bin/with-nix-daemon
RUN chmod +x /usr/local/bin/with-nix-daemon

# --- Home-manager switch ---
# Layer caching: flake inputs (rarely change) before home configs (change often)
COPY --chown=iorlas:iorlas flake.nix flake.lock /home/iorlas/nixos-config/
COPY --chown=iorlas:iorlas home/ /home/iorlas/nixos-config/home/
COPY --chown=iorlas:iorlas hosts/fox/ /home/iorlas/nixos-config/hosts/fox/

# Build and activate home-manager (cache nix store across builds)
WORKDIR /home/iorlas/nixos-config
SHELL ["/bin/bash", "-c"]
RUN --mount=type=cache,target=/nix/store,sharing=locked \
    with-nix-daemon bash -c '\
    nix build .#homeConfigurations.fox.activationPackage --no-link \
    && ACTIVATE=$(nix path-info .#homeConfigurations.fox.activationPackage) \
    && su -l -c "export PATH=/nix/var/nix/profiles/default/bin:\$PATH && $ACTIVATE/activate" iorlas'

# --- Claude Code ---
RUN --mount=type=cache,target=/nix/store,sharing=locked \
    with-nix-daemon su -l -c '\
    export PATH=/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$HOME/.npm-global/bin:$PATH \
    && mkdir -p $HOME/.npm-global \
    && npm config set prefix $HOME/.npm-global \
    && npm install -g @anthropic-ai/claude-code' iorlas

# --- Clean up ---
RUN --mount=type=cache,target=/nix/store,sharing=locked \
    with-nix-daemon bash -c '\
    nix-collect-garbage -d \
    && nix store optimise'

# --- Enable services ---
RUN systemctl enable ssh docker

STOPSIGNAL SIGRTMIN+3
SHELL ["/bin/sh", "-c"]
ENTRYPOINT ["/sbin/init"]
