#!/usr/bin/env bash

set -u

headscale_url="https://ssh.mansten.com"
profile_name="headscale"
profile_id_hint="1a50"
waybar_signal=9

refresh_waybar() {
    /usr/bin/pkill "-RTMIN+$waybar_signal" waybar 2>/dev/null || true
}

notify() {
    /usr/bin/notify-send "Headscale" "$1"
}

backend_state() {
    /usr/bin/tailscale status --json 2>/dev/null | /usr/bin/jq -r '.BackendState // "Unknown"'
}

control_url() {
    /usr/bin/tailscale debug prefs 2>/dev/null | /usr/bin/jq -r '.ControlURL // empty' | /usr/bin/sed 's:/*$::'
}

is_connected() {
    [[ "$(backend_state)" == "Running" && "$(control_url)" == "$headscale_url" ]]
}

open_reauth_terminal() {
    /usr/bin/kitty \
        --class headscale-login \
        --title "Headscale Login" \
        /usr/bin/bash -lc '
            echo "Reauthenticating the existing Headscale profile…"
            echo
            /usr/bin/tailscale up \
                --login-server=https://ssh.mansten.com \
                --accept-dns=false \
                --operator=ja
            result=$?
            echo
            if (( result == 0 )); then
                echo "Headscale connected."
            else
                echo "Login did not complete (exit $result)."
            fi
            echo
            read -r -p "Press Enter to close…"
        ' &
}

if is_connected; then
    action="Disconnect"
else
    action="Connect"
fi

choice=$(printf '%s\n' "$action" | /usr/bin/wofi \
    --show dmenu \
    --prompt "Headscale" \
    --width 240 \
    --height 100 2>/dev/null) || exit 0

[[ "$choice" == "$action" ]] || exit 0

if ! profiles_json=$(/usr/bin/tailscale switch --list --json 2>/dev/null); then
    notify "Headscale profile access needs repair. Run:\nsudo tailscale switch 1a50\nsudo tailscale set --operator=ja"
    exit 1
fi

profile_id=$(/usr/bin/jq -r \
    --arg id "$profile_id_hint" \
    --arg nickname "$profile_name" \
    '([.[] | select(.id == $id)] + [.[] | select(.nickname == $nickname)])[0].id // empty' \
    <<<"$profiles_json")

if [[ -z "$profile_id" ]]; then
    notify "The saved Headscale profile is missing. The widget will not create or replace profiles automatically."
    exit 1
fi

if [[ "$action" == "Disconnect" ]]; then
    if output=$(/usr/bin/tailscale down 2>&1); then
        notify "Disconnected"
    else
        notify "Could not disconnect:\n$output"
    fi
    refresh_waybar
    exit 0
fi

selected_profile_id=$(/usr/bin/jq -r '.[] | select(.selected) | .id' <<<"$profiles_json")
switch_output=""

if [[ "$selected_profile_id" != "$profile_id" ]]; then
    switch_output=$(/usr/bin/timeout 20s /usr/bin/tailscale switch "$profile_id" 2>&1) || true
fi

state=$(backend_state)

if is_connected; then
    notify "Connected"
elif [[ "$state" == "NeedsLogin" ]]; then
    open_reauth_terminal
elif output=$(/usr/bin/timeout 20s /usr/bin/tailscale up 2>&1); then
    if is_connected; then
        notify "Connected"
    else
        notify "Headscale did not reach the connected state."
    fi
else
    notify "Could not connect:\n${output:-$switch_output}"
fi

refresh_waybar
