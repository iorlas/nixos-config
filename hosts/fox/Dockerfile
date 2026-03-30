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
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
    && rm -f /etc/systemd/system/*.wants/* \
    && rm -f /lib/systemd/system/local-fs.target.wants/* \
    && rm -f /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -f /lib/systemd/system/basic.target.wants/*

# --- User setup ---
RUN useradd -m -s /bin/bash -G sudo,docker iorlas \
    && echo "iorlas ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/iorlas \
    && chmod 440 /etc/sudoers.d/iorlas

# --- SSH authorized keys from GitHub (staged for first-boot copy) ---
RUN mkdir -p /etc/fox-defaults/.ssh \
    && curl -fsSL https://github.com/iorlas.keys > /etc/fox-defaults/.ssh/authorized_keys \
    && chmod 600 /etc/fox-defaults/.ssh/authorized_keys

# --- SSH host key persistence service ---
COPY hosts/fox/systemd/fox-ssh-keys.service /etc/systemd/system/
RUN systemctl enable fox-ssh-keys.service

# --- Disable password auth ---
RUN sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# --- Install Nix (single-user/root-only for Docker build) ---
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --no-confirm --init none --mode root-only

# --- Home-manager switch (layer caching: flake inputs first) ---
COPY --chown=iorlas:iorlas flake.nix flake.lock /home/iorlas/nixos-config/
COPY --chown=iorlas:iorlas home/ /home/iorlas/nixos-config/home/
COPY --chown=iorlas:iorlas hosts/fox/ /home/iorlas/nixos-config/hosts/fox/

USER iorlas
WORKDIR /home/iorlas/nixos-config
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && nix build .#homeConfigurations.fox.activationPackage --no-link \
    && "$(nix path-info .#homeConfigurations.fox.activationPackage)"/activate

# --- Claude Code ---
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && export PATH="$HOME/.nix-profile/bin:$HOME/.npm-global/bin:$PATH" \
    && mkdir -p /home/iorlas/.npm-global \
    && npm config set prefix /home/iorlas/.npm-global \
    && pnpm add -g @anthropic-ai/claude-code

USER root

# --- Clean up nix store ---
RUN . /nix/var/nix/profiles/default/etc/profile.d/nix.sh \
    && nix-collect-garbage -d \
    && nix store optimise

# --- Enable services ---
RUN systemctl enable ssh docker

STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/sbin/init"]
