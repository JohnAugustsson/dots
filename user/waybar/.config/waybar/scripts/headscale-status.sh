#!/usr/bin/env bash

set -u

headscale_url="https://ssh.mansten.com"
headscale_domain="tail.mansten.com"
icon="󰖂"

status_json=$(/usr/bin/tailscale status --json 2>/dev/null || true)
prefs_json=$(/usr/bin/tailscale debug prefs 2>/dev/null || true)

if [[ -z "$status_json" ]]; then
    /usr/bin/jq -cn \
        --arg text "$icon" \
        --arg tooltip "Headscale unavailable\nTailscale is not responding" \
        --arg class "error" \
        '{text: $text, tooltip: $tooltip, class: $class}'
    exit 0
fi

backend=$(/usr/bin/jq -r '.BackendState // "Unknown"' <<<"$status_json")
control_url=$(/usr/bin/jq -r '.ControlURL // empty' <<<"$prefs_json")
dns_name=$(/usr/bin/jq -r '.Self.DNSName // empty' <<<"$status_json")
tailnet_ip=$(/usr/bin/jq -r '.Self.TailscaleIPs[0] // empty' <<<"$status_json")

control_url=${control_url%/}
dns_name=${dns_name%.}

if [[ "$backend" == "Running" ]] && { [[ "$control_url" == "$headscale_url" ]] || [[ "$dns_name" == *".$headscale_domain" ]]; }; then
    tooltip="Headscale connected"
    [[ -n "$tailnet_ip" ]] && tooltip+="\n$tailnet_ip"
    class="connected"
elif [[ "$backend" == "Starting" ]]; then
    tooltip="Headscale connecting…"
    class="connecting"
elif [[ "$backend" == "Running" ]]; then
    tooltip="Headscale disconnected\nAnother Tailscale network is active"
    class="other"
else
    tooltip="Headscale disconnected\nClick to connect"
    class="disconnected"
fi

/usr/bin/jq -cn \
    --arg text "$icon" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class}'
