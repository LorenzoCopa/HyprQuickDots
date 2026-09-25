#!/usr/bin/env bash
#
# install/lib.sh — Funciones compartidas por install.sh
#
# Proporciona la infraestructura de logging, detección de distro, manejo de
# flags (--dry-run), comprobación de dependencias, instalación de paquetes
# (pacman + AUR) y utilidades de interacción con el usuario.
#
# No es un script ejecutable por sí solo: se hace `source` desde install.sh.

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Variables globales (sobrescribibles por install.sh)
# ─────────────────────────────────────────────────────────────
DRY_RUN=false
INTERACTIVE=true
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

# ─────────────────────────────────────────────────────────────
# Colores
# ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then
	C_RESET=$'\033[0m'
	C_BOLD=$'\033[1m'
	C_DIM=$'\033[2m'
	C_RED=$'\033[31m'
	C_GREEN=$'\033[32m'
	C_YELLOW=$'\033[33m'
	C_BLUE=$'\033[34m'
	C_CYAN=$'\033[36m'
else
	C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""
fi

# ─────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────
info() {
	printf '%s==>%s %s\n' "$C_BOLD$C_BLUE" "$C_RESET" "$*"
}
ok() {
	printf '%s[OK]%s %s\n' "$C_GREEN" "$C_RESET" "$*"
}
warn() {
	printf '%s[ATENCION]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2
}
error() {
	printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2
}
die() {
	error "$*"
	exit 1
}
section() {
	echo
	printf '%s──────────────────────────────────────────────%s\n' "$C_CYAN" "$C_RESET"
	printf '%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"
	[ -n "${2:-}" ] && printf '%s%s%s\n' "$C_DIM" "$2" "$C_RESET"
	printf '%s──────────────────────────────────────────────%s\n' "$C_CYAN" "$C_RESET"
}

# ─────────────────────────────────────────────────────────────
# Header / resumen de sección
# ─────────────────────────────────────────────────────────────
step_banner() {
	local num="$1" total="$2" title="$3" desc="$4"
	section "[$num/$total] $title" "$desc"
}

# Contador de pasos dinámico (para el modo --menu, donde no todos
# los pasos se ejecutan). Se resetea con step_reset() y cada paso
# llamando a step_begin() incrementa y usa el total dado.
STEP_COUNT=0
STEP_TOTAL=0
step_reset() {
	STEP_COUNT=0
	STEP_TOTAL="$1"
}
step_begin() {
	STEP_COUNT=$((STEP_COUNT + 1))
	section "[$STEP_COUNT/$STEP_TOTAL] $1" "${2:-}"
}

# ─────────────────────────────────────────────────────────────
# Detección de distro / gestor de paquetes
# ─────────────────────────────────────────────────────────────
detect_distro() {
	if command -v pacman >/dev/null 2>&1; then
		if [ -f /etc/os-release ]; then
			local id
			id="$(. /etc/os-release && echo "$ID")"
			case "$id" in
				cachyos*) echo "cachyos" ;;
				arch*|endeavouros|artix|garuda) echo "arch" ;;
				*) echo "arch" ;;
			esac
		else
			echo "arch"
		fi
	else
		echo "unknown"
	fi
}

has_pkg() {
	pacman -Qi "$1" >/dev/null 2>&1
}

# Instala paquetes del repositorio oficial: pacman -S --needed <pkgs...>
pac_install() {
	[ "$#" -eq 0 ] && return 0
	local missing=()
	local pkg
	for pkg in "$@"; do
		if ! has_pkg "$pkg"; then
			missing+=("$pkg")
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
# Comprobación de dependencias presentes
# ─────────────────────────────────────────────────────────────
check_cmd() {
	local bin="$1" pkg="${2:-$1}"
	if command -v "$bin" >/dev/null 2>&1; then
		ok "$bin presente"
		return 0
	fi
	error "falta '$bin' (paquete: $pkg)"
	return 1
}

# Comprueba que hay un binario, y si no, ofrece instalarlo con pacman
require_cmd() {
	local bin="$1" pkg="${2:-$1}"
	if command -v "$bin" >/dev/null 2>&1; then
		return 0
	fi
	error "falta '$bin' (paquete: $pkg)"
	if "$INTERACTIVE"; then
		if confirm_run "¿Instalar $pkg?"; then
			pac_install "$pkg"
			return 0
		fi
	fi
	return 1
}

# ─────────────────────────────────────────────────────────────
# Interacción con el usuario
# ─────────────────────────────────────────────────────────────
# confirm "pregunta?" -> 0 (si) / 1 (no). En no-interactivo asume si.
confirm() {
	local prompt="$1" default="${2:-y}"
	if ! "$INTERACTIVE"; then
		return 0
	fi
	local ans
	while true; do
		printf '%s [%s/%s] ' "$prompt" "${C_GREEN}Y${C_RESET}" "${C_RED}n${C_RESET}"
		if ! read -r ans; then
			# EOF (sin más entrada): usar el valor por defecto y continuar
			echo
			case "$default" in
				y|Y|s|S) return 0 ;;
				*) return 1 ;;
			esac
		fi
		case "${ans:-$default}" in
			y|Y|yes|YES|s|S|si|SI) return 0 ;;
			n|N|no|NO) return 1 ;;
			*) echo "  Responde 'y' o 'n'." ;;
		esac
	done
}

# Igual pero respeta --dry-run: pregunta siempre, pero no ejecuta nada
confirm_run() {
	local prompt="$1"
	if ! "$INTERACTIVE"; then
		return 0
	fi
	confirm "$prompt" && return 0
	printf '  [skip] %s\n' "$prompt"
	return 1
}

# ─────────────────────────────────────────────────────────────
# Copiado / enlazado idempotente
# ─────────────────────────────────────────────────────────────
# link_file <src> <dst>: crea symlink, respaldando un real existente a .bak
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
	ok "enlazado: $dst"
}

# Ejecuta un comando respetando --dry-run
run() {
	if "$DRY_RUN"; then
		printf '  [dry-run] %s\n' "$*"
	else
		printf '  %s\n' "$*"
		"$@"
	fi
}
