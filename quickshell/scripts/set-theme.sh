#!/bin/sh
# Aplica el tema de aplicaciones (GTK + Qt)
# Uso: set-theme.sh [dark|light|system|get]
#
# Fuente de verdad: gsettings (org.gnome.desktop.interface).
#  - GTK3/GTK4/libadwaita leen color-scheme + gtk-theme.
#  - Qt (QT_QPA_PLATFORMTHEME=xdgdesktopportal) lee el color-scheme a
#    través del xdg-desktop-portal (backend gtk -> gsettings), así que
#    las apps Qt detectan el modo oscuro del sistema y cambian en vivo.

STATE_FILE="$HOME/.config/theme-mode"
DEFAULT_MODE="dark"

write_settings_ini() {
    theme="$1"
    dark="$2"
    mkdir -p "$HOME/.config/gtk-3.0"
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$theme
gtk-application-prefer-dark-theme=$dark
gtk-cursor-theme-name=Adwaita
EOF
}

case "${1:-$DEFAULT_MODE}" in
    dark)
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
        write_settings_ini adw-gtk3-dark 1
        echo dark > "$STATE_FILE"
        ;;
    light)
        gsettings set org.gnome.desktop.interface color-scheme prefer-light
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3
        write_settings_ini adw-gtk3 0
        echo light > "$STATE_FILE"
        ;;
    system)
        gsettings set org.gnome.desktop.interface color-scheme default
        gsettings set org.gnome.desktop.interface gtk-theme Adwaita
        write_settings_ini Adwaita 0
        echo system > "$STATE_FILE"
        ;;
    get)
        if [ -f "$STATE_FILE" ]; then
            cat "$STATE_FILE"
        else
            echo "$DEFAULT_MODE"
        fi
        ;;
    *)
        echo "Uso: set-theme.sh [dark|light|system|get]" >&2
        exit 1
        ;;
esac
