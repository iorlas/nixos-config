#!/usr/bin/env bash
# Check: DNS (Quad9 DNS-over-TLS)

check_dns_quad9() {
  echo "==> DNS"
  if systemctl is-active --quiet systemd-resolved; then
    local dns_servers
    dns_servers=$(resolvectl status 2>/dev/null | grep "DNS Servers" | head -1 || echo "")
    if echo "$dns_servers" | grep -q "9.9.9.9"; then
      ok "DNS-over-TLS via Quad9"
    else
      warn "DNS not using Quad9: $dns_servers"
      hint "This should be configured by NixOS. Run: bootstrap"
    fi
  else
    warn "systemd-resolved not running — DNS may leak through corporate resolver"
    hint "This should be configured by NixOS. Run: bootstrap"
  fi
}
