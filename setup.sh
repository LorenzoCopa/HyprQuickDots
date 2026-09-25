#!/usr/bin/env bash
#
# setup.sh — Instala/repare los symlinks de HyprQuickDots.
#
# Crea (o repara) los enlaces simbólicos que van del repo a ~/.config y a
# ~/.local/share/applications, según la tabla de AGENTS.md. Es idempotente:
# se puede ejecutar las veces que quieras sin romper nada. Si un destino ya
# existe como archivo/carpeta real (no symlink), lo respalda con sufijo .bak
# antes de reemplazarlo.
#
# Uso:
#   ./setup.sh            # hace todo lo que no requiere sudo
#   ./setup.sh --sddm     # además copia el tema SDDM (requiere sudo)
#   ./setup.sh --dry-run  # solo muestra lo que haría, sin cambiar nada
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APPS_DIR="$HOME/.local/share/applications"

DRY_RUN=false
WITH_SDDM=false
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY_RUN=true ;;
		--sddm) WITH_SDDM=true ;;
		*) echo "Argumento desconocido: $arg" >&2; exit 1 ;;
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

# Crea un symlink de archivo enlazando `src` -> `dst`.
# Si `dst` ya existe y no es symlink, lo respalda a `dst.bak`.
link_file() {
	local src="$1" dst="$2"
	local dst_dir; dst_dir="$(dirname "$dst")"
	if [ ! -d "$dst_dir" ]; then
		run mkdir -p "$dst_dir"
	fi
	if [ -e "$dst" ] && [ ! -L "$dst" ]; then
		run mv "$dst" "$dst.bak"
	fi
	run ln -sfn "$src" "$dst"
}

# Igual que link_file pero para directorios
link_dir() {
	link_file "$@"
}

# Crea el symlink de un directorio de config del repo
config_dir() {
	local name="$1"
	link_dir "$REPO_DIR/$name" "$CONFIG_HOME/$name"
}

# Crea el symlink de un archivo único del repo bajo ~/.config
config_file() {
	local rel="$1" # ruta relativa en el repo (p. ej. starship/starship.toml)
	link_file "$REPO_DIR/$rel" "$CONFIG_HOME/$(basename "$rel")"
}

echo "==> Repo:      $REPO_DIR"
echo "==> Config:    $CONFIG_HOME"
echo "==> Apps .desktop: $APPS_DIR"
echo

# ── ~/.config: directorios de config ─────────────────────────────
for dir in fish hypr kitty pipewire quickshell uwsm wireplumber zellij; do
	config_dir "$dir"
done

# ── ~/.config: archivos únicos ───────────────────────────────────
config_file starship/starship.toml

# ── ~/.local/share/applications: entradas .desktop ──────────────
for entry in aplicaciones.desktop qs-settings.desktop; do
	link_file "$REPO_DIR/applications/$entry" "$APPS_DIR/$entry"
done

# ── SDDM: tema (copia real, requiere sudo) ──────────────────────
if "$WITH_SDDM"; then
	echo "==> Instalando tema SDDM (requiere sudo)..."
	if "$DRY_RUN"; then
		echo "  [dry-run] sudo cp -r $REPO_DIR/sddm/evergarden/. /usr/share/sddm/themes/evergarden/"
	else
		sudo mkdir -p /usr/share/sddm/themes/evergarden
		sudo cp -r "$REPO_DIR/sddm/evergarden/." /usr/share/sddm/themes/evergarden/
	fi
else
	echo "==> SDDM no tocado (usa: ./setup.sh --sddm)"
fi

echo "==> Listo."