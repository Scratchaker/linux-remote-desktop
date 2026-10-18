#!/usr/bin/env bash
set -e

trap 'cleanup' EXIT
cleanup() {
    systemctl --user restart xdg-document-portal xdg-desktop-portal
}

# Get resolution
PLASMA_WIDTH=${POLARIS_CLIENT_WIDTH:-1920}
PLASMA_HEIGHT=${POLARIS_CLIENT_HEIGHT:-1080}

# Write wrapper
mkdir -p "$XDG_RUNTIME_DIR/nested-plasma"

cat > "$XDG_RUNTIME_DIR/nested-plasma/kwin_wayland_wrapper" <<EOF
#!/usr/bin/env bash
exec /usr/bin/kwin_wayland_wrapper \
    --width "$PLASMA_WIDTH" \
    --height "$PLASMA_HEIGHT" \
    --no-lockscreen "\$@"
EOF
chmod +x "$XDG_RUNTIME_DIR/nested-plasma/kwin_wayland_wrapper"

# pkexec management
cat > "$XDG_RUNTIME_DIR/nested-plasma/sudo-askpass" <<'EOF'
#!/usr/bin/env bash
if command -v kdialog >/dev/null 2>&1; then
    if password=$(kdialog --title "Authentication Required" --password "Type your password"); then
        echo "$password"
    else
        exit 1
    fi
elif command -v zenity >/dev/null 2>&1; then
    zenity --password --title="Authentication Required"
else
    echo "No supported dialog tool found (kdialog or zenity)" >&2
    exit 1
fi
EOF
chmod +x "$XDG_RUNTIME_DIR/nested-plasma/sudo-askpass"

export SUDO_ASKPASS="$XDG_RUNTIME_DIR/nested-plasma/sudo-askpass"

cat > "$XDG_RUNTIME_DIR/nested-plasma/pkexec" <<'EOF'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
    case "$1" in
        --disable-internal-agent|--keep-cwd)
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "pkexec shim: unsupported flag '$1'" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "pkexec shim: no command given" >&2
    exit 1
fi
exec sudo -k -A "$@"
EOF
chmod +x "$XDG_RUNTIME_DIR/nested-plasma/pkexec"

# Chromium-based browsers: disable GPU compositing
for browser in "chromium" "google-chrome-stable" "google-chrome" "brave" "brave-browser" "microsoft-edge-stable" "vivaldi-stable"; do
    real="/usr/bin/$browser"
    [ -x "$real" ] || continue
    cat > "$XDG_RUNTIME_DIR/nested-plasma/$browser" <<EOF
#!/usr/bin/env bash
exec "$real" --disable-gpu-compositing "\$@"
EOF
    chmod +x "$XDG_RUNTIME_DIR/nested-plasma/$browser"
done
# Flatpak Chromium-based browsers: disable GPU compositing
cat > "$XDG_RUNTIME_DIR/nested-plasma/flatpak" <<'EOF'
#!/usr/bin/env bash
real="$XDG_RUNTIME_DIR/nested-plasma/real-flatpak"
[ "$1" = "run" ] || exec "$real" "$@"

new_arg="--disable-gpu-compositing"

args=("$@")
result=()

for arg in "${args[@]}"; do
    result+=("$arg")

    case "$arg" in
        org.chromium.Chromium|com.google.Chrome|com.brave.Browser|com.microsoft.Edge|com.vivaldi.Vivaldi|io.github.ungoogled_software.ungoogled_chromium)
            result+=("$new_arg")
        ;;
    esac
done

exec "$real" "${result[@]}"
EOF
chmod +x "$XDG_RUNTIME_DIR/nested-plasma/flatpak"


# Path
export PATH="$XDG_RUNTIME_DIR/nested-plasma:$PATH"

# Exports
export XDG_SESSION_DESKTOP=KDE
export DESKTOP_SESSION=plasma
export XDG_SEAT=seat0
export XDG_SESSION_CLASS=user

# Run Plasma
dbus-run-session startplasma-wayland &
