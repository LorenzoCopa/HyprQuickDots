#!/usr/bin/env bash
#
# install-cli.sh — Instalador CLI de respaldo de HyprQuickDots (CachyOS/Arch)
#
# Versión simple y directa para terminal (sin interfaz / sin menú), en la
# línea de los clásicos comandos del tutorial original. Hace lo mismo que
# install.sh pero en bloque: instala TODOS los paquetes, luego fuentes,
# fontconfig, servicios systemd, symlinks (setup.sh) y SDDM.
#
# Uso:
#   ./install-cli.sh                  # instala todo (sin preguntar por gaming/sddm)
#   ./install-cli.sh --no-whisper     # no instala whisper ni descarga modelo
#   ./install-cli.sh --no-sddm        # no toca el tema SDDM
#   ./install-cli.sh --no-gaming      # no instala cachyos-gaming-meta/steam
#   ./install-cli.sh --dry-run        # solo muestra los comandos, sin ejecutar
#   ./install-cli.sh --help
#
# Nota: por defecto instala gaming y SDDM (a diferencia de install.sh, que
# pregunta). Usa --no-gaming / --no-sddm para excluirlos.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DO_WHISPER=true
DO_SDDM=true
DO_GAMING=true
DRY_RUN=false
INTERACTIVE="auto"

# Colores
if [ -t 1 ]; then
	C=$'\033[1m'; CE=$'\033[0m'; CY=$'\033[0;36m'; CG=$'\033[0;32m'; CYT=$'\033[0;33m'; CR=$'\033[0;31m'
else
	C=""; CE=""; CY=""; CG=""; CYT=""; CR=""
fi

info()  { printf '%s==>%s %s\n' "$CY" "$CE" "$*"; }
ok()    { printf '%s[OK]%s %s\n' "$CG" "$CE" "$*"; }
warn()  { printf '%s[AVISO]%s %s\n' "$CYT" "$CE" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "$CR" "$CE" "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
	cat <<'EOF'
Uso: ./install-cli.sh [opciones]

Instalador CLI de respaldo de HyprQuickDots (CachyOS/Arch).

Opciones:
  --no-whisper   No instala whisper ni descarga modelo
  --no-sddm      No copia el tema SDDM
  --no-gaming    No instala cachyos-gaming-meta / steam
  --dry-run      Solo muestra los comandos, sin ejecutar nada
  --help         Muestra esta ayuda
EOF
}

for arg in "$@"; do
	case "$arg" in
		--no-whisper) DO_WHISPER=false ;;
		--no-sddm) DO_SDDM=false ;;
		--no-gaming) DO_GAMING=false ;;
		--dry-run) DRY_RUN=true ;;
		--help|-h) usage; exit 0 ;;
		*) echo "Argumento desconocido: $arg" >&2; usage >&2; exit 1 ;;
	esac
done

# Ejecuta un comando respetando --dry-run
run() {
	if "$DRY_RUN"; then
		printf '  [dry-run] %s\n' "$*"
	else
		printf '  %s\n' "$*"
		"$@"
	fi
}

pac_install() {
	[ "$#" -eq 0 ] && return 0
	local missing=() pkg exist=0
	for pkg in "$@"; do
		if ! pacman -Qi "$pkg" >/dev/null 2>&1; then
			missing+=("$pkg")
		else
			exist=1
		fi
	done
	if [ "${#missing[@]}" -eq 0 ]; then
		ok "ya instalados: $*"
		return 0
	fi
	if "$DRY_RUN"; then
		printf '  [dry-run] sudo pacman -S --needed --noconfirm %s\n' "${missing[*]}"
		return 0
	fi
	sudo pacman -S --needed --noconfirm "${missing[@]}"
	ok "instalados: ${missing[*]}"
}

# ─────────────────────────────────────────────────────────────
# 1) Preflight
# ─────────────────────────────────────────────────────────────
info "Instalador CLI de HyprQuickDots"
if "$DRY_RUN"; then warn "Modo --dry-run: no se cambia nada."; fi

command -v pacman >/dev/null 2>&1 || die "No hay pacman; ¿sistema Arch-based?"
[ "$(id -u)" -eq 0 ] && die "No ejecutar como root."
command -v sudo >/dev/null 2>&1 || die "No hay sudo."

# ─────────────────────────────────────────────────────────────
# 2) Paquetes del sistema (todo en un solo bloque --needed)
# ─────────────────────────────────────────────────────────────
echo
info "Instalando paquetes del sistema..."

pac_install \
	fish uwsm git base-devel xdg-desktop-portal-hyprland wl-clipboard curl python unzip \
	hyprland pipewire pipewire-pulse pipewire-alsa wireplumber playerctl \
	bluez bluez-utils networkmanager pam \
	fnm zoxide neovim lazygit tree-sitter-cli fzf ripgrep fd opencode \
	kitty zellij starship ttf-nerd-fonts-symbols ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd \
	qt6-tools qt6-declarative qt6ct adw-gtk-theme papirus-icon-theme unixodbc \
	hyprshot grim swappy tesseract tesseract-data-spa tesseract-data-eng hyprpicker \
	cliphist awww hyprsunset brightnessctl lm_sensors power-profiles-daemon

# quickshell (repos oficiales de CachyOS)
pac_install quickshell

# Dictado / whisper (si no --no-whisper)
if "$DO_WHISPER"; then
	info "Instalando whisper (dictado por voz)..."
	pac_install whisper-cpp ggml ggml-cpu ggml-vulkan vulkan-icd-loader ffmpeg
else
	warn "--no-whisper: no se instala whisper ni el modelo."
fi

# Gaming (si no --no-gaming)
if "$DO_GAMING"; then
	if command -v pacman >/dev/null 2>&1 && pacman -Q cachyos-gaming-meta >/dev/null 2>&1; then
		ok "gaming ya instalado"
	else
		info "Instalando gaming (cachyos-gaming-meta + steam)..."
		pac_install cachyos-gaming-meta steam
	fi
else
	warn "--no-gaming: no se instala gaming."
fi

# ─────────────────────────────────────────────────────────────
# 3) Modelo de whisper (interactivo, solo si --no-whisper no se pasó)
# ─────────────────────────────────────────────────────────────
if "$DO_WHISPER"; then
	models_dir="$HOME/.local/share/dictation/models"
	run mkdir -p "$models_dir"
	model="ggml-medium-q8_0.bin"
	dest="$models_dir/$model"
	if [ -f "$dest" ]; then
		ok "Modelo de whisper ya presente: $dest"
	else
		info "Descargando modelo de whisper: $model (~786 MB)..."
		if "$DRY_RUN"; then
			printf '  [dry-run] curl -L --fail --progress-bar -o %s https://huggingface.co/ggerganov/whisper.cpp/resolve/main/%s\n' "$dest" "$model"
		else
			curl -L --fail --progress-bar -o "$dest" \
				"https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$model"
			ok "Modelo descargado: $dest"
		fi
	fi
fi

# ─────────────────────────────────────────────────────────────
# 4) Fuentes locales (Rubik si existe) + fc-cache
# ─────────────────────────────────────────────────────────────
echo
info "Instalando fuentes locales..."
fonts_dir="$HOME/.local/share/fonts"
run mkdir -p "$fonts_dir"
if [ -f "$REPO_DIR/fonts/Rubik.zip" ]; then
	run unzip -o "$REPO_DIR/fonts/Rubik.zip" -d "/tmp/qs-rubik"
	run cp -r "/tmp/qs-rubik/." "$fonts_dir/"
	run rm -rf "/tmp/qs-rubik"
else
	warn "No hay fonts/Rubik.zip; se omiten las fuentes locales adicionales."
fi
if "$DRY_RUN"; then
	printf '  [dry-run] fc-cache -fv\n'
else
	fc-cache -fv >/dev/null 2>&1 || true
fi

# ─────────────────────────────────────────────────────────────
# 5) fontconfig (Dota 2)
# ─────────────────────────────────────────────────────────────
if [ -f "$REPO_DIR/fontconfig/fonts.conf" ]; then
	info "Instalando fontconfig (Dota 2)..."
	run mkdir -p "$HOME/.config/fontconfig"
	if [ -e "$HOME/.config/fontconfig/fonts.conf" ] && [ ! -L "$HOME/.config/fontconfig/fonts.conf" ]; then
		run mv "$HOME/.config/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf.bak"
	fi
	run ln -sfn "$REPO_DIR/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"
	if ! "$DRY_RUN"; then fc-cache -fv >/dev/null 2>&1 || true; else printf '  [dry-run] fc-cache -fv\n'; fi
fi

# ─────────────────────────────────────────────────────────────
# 6) Servicios systemd (quickshell + awww)
# ─────────────────────────────────────────────────────────────
echo
info "Instalando servicios systemd de usuario..."
service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
run mkdir -p "$service_dir"
for fname in quickshell.service awww.service; do
	if [ -f "$REPO_DIR/systemd-user/$fname" ]; then
		if [ -e "$service_dir/$fname" ] && [ ! -L "$service_dir/$fname" ]; then
			run mv "$service_dir/$fname" "$service_dir/$fname.bak"
		fi
		run ln -sfn "$REPO_DIR/systemd-user/$fname" "$service_dir/$fname"
	fi
done
if "$DRY_RUN"; then
	printf '  [dry-run] systemctl --user daemon-reload\n'
	printf '  [dry-run] systemctl --user enable quickshell awww\n'
else
	systemctl --user daemon-reload
	systemctl --user enable quickshell awww
	ok "Servicios habilitados: quickshell, awww"
fi

# ─────────────────────────────────────────────────────────────
# 7) Symlinks de configuración (setup.sh)
# ─────────────────────────────────────────────────────────────
echo
info "Enlazando configuración (setup.sh)..."
[ -f "$REPO_DIR/setup.sh" ] || die "Falta setup.sh"
if "$DRY_RUN"; then
	bash "$REPO_DIR/setup.sh" --dry-run
else
	bash "$REPO_DIR/setup.sh"
fi
if command -v hyprctl >/dev/null 2>&1 && hyprctl activeworkspace >/dev/null 2>&1; then
	run hyprctl reload
fi

# ─────────────────────────────────────────────────────────────
# 8) SDDM (si no --no-sddm)
# ─────────────────────────────────────────────────────────────
if "$DO_SDDM"; then
	echo
	info "Instalando tema SDDM evergarden..."
	theme_src="$REPO_DIR/sddm/evergarden"
	theme_dst="/usr/share/sddm/themes/evergarden"
	if [ -d "$theme_src" ]; then
		if "$DRY_RUN"; then
			printf '  [dry-run] sudo mkdir -p %s\n' "$theme_dst"
			printf '  [dry-run] sudo cp -r %s/. %s/\n' "$theme_src" "$theme_dst"
			printf '  [dry-run] sudo cp %s/sddm.conf /etc/sddm.conf.d/10-hyprquickdots.conf\n' "$REPO_DIR"
		else
			sudo mkdir -p "$theme_dst"
			sudo cp -r "$theme_src/." "$theme_dst/"
			sudo mkdir -p /etc/sddm.conf.d
			[ -f "$REPO_DIR/sddm.conf" ] && sudo cp "$REPO_DIR/sddm.conf" /etc/sddm.conf.d/10-hyprquickdots.conf
			ok "SDDM configurado"
		fi
	fi
else
	warn "--no-sddm: no se toca SDDM."
fi

# ─────────────────────────────────────────────────────────────
# 9) Resumen
# ─────────────────────────────────────────────────────────────
echo
echo "================================================================"
echo "  RESUMEN"
echo "================================================================"
info "Verificación:"
echo "  systemctl --user status quickshell"
echo "  qs log"
echo "  hyprctl reload"
if "$DO_WHISPER" && [ ! -f "$HOME/.local/share/dictation/models/"*.bin ] && ! "$DRY_RUN"; then
	warn "No hay modelo de whisper. Está pendiente de descargar."
fi
if ! "$DRY_RUN"; then
	echo
	info "Reinicia la sesión para aplicar todo: uwsm stop"
fi
echo "================================================================"

exit 0
