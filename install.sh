#!/usr/bin/env bash
#
# install.sh — Instalador interactivo de HyprQuickDots (CachyOS/Arch)
#
# Un solo comando que deja TODO funcionando: dependencias, Quickshell,
# fuentes, dictado por voz (whisper), wallpaper, servicios systemd,
# symlinks de configuración y tema SDDM.
#
# Uso:
#   ./install.sh                  # flujo completo e interactivo
#   ./install.sh --menu           # elige qué secciones instalar (menú)
#   ./install.sh --no-whisper     # salta la sección de dictado (modelo)
#   ./install.sh --no-sddm        # no toca el tema SDDM
#   ./install.sh --no-gaming      # no pregunta por cachyos-gaming-meta/steam
#   ./install.sh --no-interactive # no pregunta; instala todo (sin gaming/sddm)
#   ./install.sh --dry-run        # solo muestra lo que haría
#   ./install.sh --help
#
# Guías usadas: tutorial/dictado.md (whisper), AGENTS.md (arquitectura),
# nota personal de Notion "New hyprland - Quickshell".

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib.sh
source "$REPO_DIR/install/lib.sh"

# ─────────────────────────────────────────────────────────────
# Flags
# ─────────────────────────────────────────────────────────────
DO_WHISPER=true
DO_SDDM=true
DO_GAMING=true
DO_INTERACTIVE=true
DO_MENU=false

# ─────────────────────────────────────────────────────────────
# Registro de secciones (para el modo --menu)
#   secciones+=( "id|Título corto|Descripción|función|default" )
#   default: 1 = marcada por defecto, 0 = desmarcada
# ─────────────────────────────────────────────────────────────
declare -A SECTION_NAMES=()
declare -A SECTION_DESC=()
declare -A SECTION_FUNC=()
declare -A SECTION_DEFAULT=()
declare -A SECTION_STATE=()
SECTION_ORDER=()

register_section() {
	local id="$1" name="$2" desc="$3" func="$4" default="${5:-1}"
	SECTION_ORDER+=("$id")
	SECTION_NAMES["$id"]="$name"
	SECTION_DESC["$id"]="$desc"
	SECTION_FUNC["$id"]="$func"
	SECTION_DEFAULT["$id"]="$default"
	SECTION_STATE["$id"]="$default"
}

usage() {
	cat <<'EOF'
Uso: ./install.sh [opciones]

Instala y configura HyprQuickDots (CachyOS/Arch).

Opciones:
  --menu             Elige interactivamente qué secciones instalar
  --no-whisper       Salta la sección de dictado por voz (whisper y modelo)
  --no-sddm          No instala ni configura el tema SDDM
  --no-gaming        No pregunta por cachyos-gaming-meta / steam
  --no-interactive   No pregunta nada; instala todo lo no opcional
  --dry-run          Solo muestra lo que se haría, sin cambiar nada
  --help             Muestra esta ayuda
EOF
}

for arg in "$@"; do
	case "$arg" in
		--menu) DO_MENU=true ;;
		--no-whisper) DO_WHISPER=false ;;
		--no-sddm) DO_SDDM=false ;;
		--no-gaming) DO_GAMING=false ;;
		--no-interactive) DO_INTERACTIVE=false ;;
		--dry-run) DRY_RUN=true ;;
		--help|-h) usage; exit 0 ;;
		*) echo "Argumento desconocido: $arg" >&2; usage >&2; exit 1 ;;
	esac
done
INTERACTIVE="$DO_INTERACTIVE"

# ─────────────────────────────────────────────────────────────
# Paso 0 — Preflight
# ─────────────────────────────────────────────────────────────
preflight() {
	section "Preflight" "Comprueba distro, root y conexión"

	local distro; distro="$(detect_distro)"
	case "$distro" in
		cachyos|arch)
			ok "Distro compatible: $distro"
			;;
		*)
			die "No se detectó Arch/CachyOS (gestor pacman). Este instalador solo soporta Arch-based."
			;;
	esac

	if [ "$(id -u)" -eq 0 ]; then
		die "No ejecutes como root. El instalador usa sudo de forma selectiva."
	fi

	if ! command -v pacman >/dev/null 2>&1; then
		die "No se encuentra 'pacman'. ¿Es este un sistema Arch-based?"
	fi

	# Sin --no-interactive necesitamos confirmar sudo una vez antes
	command -v sudo >/dev/null 2>&1 || die "No se encuentra 'sudo'."

	if command -v curl >/dev/null 2>&1; then
		if ! curl -sI --max-time 8 https://archlinux.org >/dev/null 2>&1; then
			warn "No se pudo alcanzar internet con curl. La instalación de paquetes puede fallar."
		else
			ok "Conexión a internet verificada"
		fi
	else
		warn "No se encontró curl; no se puede verificar la conexión."
	fi

	echo
	if ! "$DRY_RUN"; then
		confirm "¿Continuar con la instalación?" || die "Cancelado por el usuario."
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 2 — Dependencias fundamentales
# ─────────────────────────────────────────────────────────────
step_fundamentales() {
	step_begin "Dependencias fundamentales" \
		"Base del sistema: shell, uwsm, git, tooling base y portal Hyprland"

	local pkgs_pac=(
		fish
		uwsm
		git
		base-devel
		xdg-desktop-portal-hyprland
		wl-clipboard
		curl
		python
		unzip
		hyprland
		pipewire
		pipewire-pulse
		pipewire-alsa
		wireplumber
		playerctl
		bluez
		bluez-utils
		networkmanager
		pam
	)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 3 — Herramientas de desarrollo
# ─────────────────────────────────────────────────────────────
step_devtools() {
	step_begin "Herramientas de desarrollo" \
		"fnm, zoxide, neovim, lazygit, tree-sitter, fzf, ripgrep, fd, opencode"

	local pkgs_pac=(
		fnm
		zoxide
		neovim
		lazygit
		tree-sitter-cli
		fzf
		ripgrep
		fd
		opencode
	)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 4 — Shell, terminal, barra y fuentes del sistema
# ─────────────────────────────────────────────────────────────
step_shell_terminal() {
	step_begin "Shell, terminal y barra" \
		"kitty, zellij, starship y Nerd Fonts del sistema"

	local pkgs_pac=(
		kitty
		zellij
		starship
		ttf-nerd-fonts-symbols
		ttf-iosevkaterm-nerd
		ttf-jetbrains-mono-nerd
	)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 5 — Quickshell + entorno Qt
# ─────────────────────────────────────────────────────────────
step_quickshell() {
	step_begin "Quickshell + entorno Qt" \
		"El shell: quickshell, Qt 6 (declarative/tools), temas Qt/GTK (adw-gtk3), papirus, unixodbc"

	local pkgs_pac=(
		quickshell
		qt6-tools
		qt6-declarative
		qt6ct
		adw-gtk-theme
		papirus-icon-theme
		unixodbc
	)
	pac_install "${pkgs_pac[@]}"

	# comprobar el binario qs (proporciona `qs ipc`, usado por los binds)
	if command -v qs >/dev/null 2>&1; then
		ok "qs (CLI de quickshell) presente"
	else
		warn "'qs' no está en PATH tras instalar quickshell; reinicia la sesión si hace falta."
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 6 — Fuentes locales (Rubik + refresco de cache)
# ─────────────────────────────────────────────────────────────
step_fuentes() {
	step_begin "Fuentes locales" \
		"Instala la fuente Rubik en ~/.local/share/fonts y refresca el cache (fc-cache)"

	local fonts_dir="$HOME/.local/share/fonts"
	run mkdir -p "$fonts_dir"

	# Si hay un zip de Rubik en el repo, extraerlo; si no, solo avisar
	if [ -f "$REPO_DIR/fonts/Rubik.zip" ]; then
		info "Extrayendo Rubik desde el repo..."
		run unzip -o "$REPO_DIR/fonts/Rubik.zip" -d "/tmp/qs-rubik"
		run cp -r "/tmp/qs-rubik/." "$fonts_dir/"
		run rm -rf "/tmp/qs-rubik"
		ok "Rubik copiada a ~/.local/share/fonts"
	else
		warn "No hay fonts/Rubik.zip en el repo. Si usas Rubik, extráela a $fonts_dir manualmente."
	fi

	# Asegurar que las Nerd Fonts del sistema están instaladas (paso 4)
	if ! "$DRY_RUN"; then
		fc-cache -fv >/dev/null 2>&1 || true
		ok "fc-cache refrescado"
	else
		printf '  [dry-run] fc-cache -fv\n'
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 7 — Configuración de fuentes (fontconfig, Dota 2)
# ─────────────────────────────────────────────────────────────
step_fontconfig() {
	step_begin "Configuración de fuentes (fontconfig)" \
		"Sustituye Arial/Tahoma/Verdana (p. ej. para Dota 2)"

	local src="$REPO_DIR/fontconfig/fonts.conf"
	local dst="$HOME/.config/fontconfig/fonts.conf"
	if [ ! -f "$src" ]; then
		warn "No hay fontconfig/fonts.conf en el repo; se omite."
		return 0
	fi
	link_file "$src" "$dst"
	if ! "$DRY_RUN"; then
		fc-cache -fv >/dev/null 2>&1 || true
		ok "fnc-cache refrescado (fontconfig)"
	else
		printf '  [dry-run] fc-cache -fv\n'
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 8 — Capturas, OCR y color
# ─────────────────────────────────────────────────────────────
step_capturas() {
	step_begin "Capturas, OCR y color" \
		"hyprshot, grim, swappy, tesseract (spa+eng), hyprpicker"

	local pkgs_pac=(
		hyprshot
		grim
		swappy
		tesseract
		tesseract-data-spa
		tesseract-data-eng
		hyprpicker
	)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 9 — Portapapeles
# ─────────────────────────────────────────────────────────────
step_portapapeles() {
	step_begin "Portapapeles" \
		"cliphist + wl-clipboard (historial y copiado en Wayland)"

	local pkgs_pac=(
		cliphist
		wl-clipboard
	)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 10 — Wallpaper (awww + servicio systemd)
# ─────────────────────────────────────────────────────────────
step_wallpaper() {
	step_begin "Wallpaper (awww)" \
		"Instala awww (el daemon awww.service se habilita en la sección de servicios)"

	local pkgs_pac=(awww)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 11 — Sistema / input / night-light
# ─────────────────────────────────────────────────────────────
step_sistema() {
	step_begin "Sistema, input y energía" \
		"hyprsunset (luz nocturna), brightnessctl, lm_sensors, power-profiles-daemon (perfil de energía)"

	local pkgs_pac=(
		hyprsunset
		brightnessctl
		lm_sensors
		power-profiles-daemon
	)
	pac_install "${pkgs_pac[@]}"
}

# ─────────────────────────────────────────────────────────────
# Paso 12 — Dictado por voz (whisper + modelo interactivo)
# ─────────────────────────────────────────────────────────────
step_dictado() {
	step_begin "Dictado por voz (whisper)" \
		"Instala los paquetes base y deja elegir el modelo (interactivo)"

	if ! "$DO_WHISPER"; then
		echo "  (saltado por --no-whisper)"
		return 0
	fi

	# Paquetes base del dictado (ver tutorial/dictado.md)
	local pkgs_pac=(
		whisper-cpp
		ggml
		ggml-cpu
		ggml-vulkan
		vulkan-icd-loader
		ffmpeg
	)
	pac_install "${pkgs_pac[@]}"

	# IMPORTANTE — gotcha ggml: si el usuario usa ggml 0.20+ los backends
	# ggml-cpu/ggml-vulkan son obligatorios (ver dictado.md). Ya los instalamos.

	# Verificar Vulkan (opcional)
	if command -v vulkaninfo >/dev/null 2>&1; then
		if vulkaninfo --summary >/dev/null 2>&1; then
			ok "Dispositivo Vulkan detectado (el dictado usará GPU)"
		else
			warn "No se detectó dispositivo Vulkan; whisper-cli usará CPU (más lento)."
		fi
	else
		warn "vulkaninfo no presente (parte de vulkan-tools); no se pudo verificar GPU."
	fi

	# Comprobar binario whisper-cli
	if ! command -v whisper-cli >/dev/null 2>&1; then
		warn "whisper-cli no está en PATH tras instalar whisper-cpp."
	fi

	# ----- Elección interactiva del modelo -----
	local models_dir="$HOME/.local/share/dictation/models"
	run mkdir -p "$models_dir"

	echo
	echo "  Se instalarán los paquetes base. Ahora elige el modelo de transcripción."
	echo "  Ruta de modelos: $models_dir (referenciada en quickshell/dictate.json)"
	echo
	echo "  Opciones (son descargas de ~50 MB a ~1.5 GB):"
	echo "   1) ggml-medium-q8_0.bin  (~786 MB)  — recomendado, buena calidad/velocidad"
	echo "   2) ggml-small-q8_0.bin   (~54 MB)   — rápido, menos preciso"
	echo "   3) ggml-large-v3-q5_0.bin (~1.5 GB) — máxima calidad, lento"
	echo "   0) No descargar modelo ahora"
	echo
	local choice=""
	if "$INTERACTIVE"; then
		while true; do
			printf '  Elige modelo [1-3, 0 para saltar]: '
			if ! read -r choice; then
				# EOF (por ej. entrada redirigida): saltar sin descargar
				choice="0"
				break
			fi
			case "$choice" in
				0|1|2|3) break ;;
				"") echo "    (enter = saltar)"; choice="0"; break ;;
				*) echo "    Opción inválida." ;;
			esac
		done
	else
		choice="1"
	fi

	local model=""
	case "$choice" in
		1) model="ggml-medium-q8_0.bin"
		   model_url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin" ;;
		2) model="ggml-small-q8_0.bin"
		   model_url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin" ;;
		3) model="ggml-large-v3-q5_0.bin"
		   model_url="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin" ;;
		0|"") warn "No se descarga ningún modelo. Podrás hacerlo luego (ver README)."; return 0 ;;
	esac

	local dest="$models_dir/$model"
	if [ -f "$dest" ]; then
		ok "Modelo ya presente: $dest"
	else
		info "Descargando $model (~${model_size:-?})..."
		if "$DRY_RUN"; then
			printf '  [dry-run] curl -L -o %s %s\n' "$dest" "$model_url"
		else
			curl -L --fail --progress-bar -o "$dest" "$model_url"
			ok "Modelo descargado: $dest"
		fi
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 13 — Gaming (opcional, pregunta)
# ─────────────────────────────────────────────────────────────
step_gaming() {
	step_begin "Gaming (opcional)" \
		"cachyos-gaming-meta + steam — MUY pesado (varios GB)"

	if ! "$DO_GAMING"; then
		echo "  (saltado por --no-gaming)"
		return 0
	fi

	if ! "$INTERACTIVE"; then
		echo "  (modo no interactivo: se omite, usa --no-gaming para silenciar)"
		return 0
	fi

	if confirm "¿Instalar gaming (cachyos-gaming-meta + steam)?"; then
		local pkgs_pac=(cachyos-gaming-meta steam)
		pac_install "${pkgs_pac[@]}"
	else
		warn "Omitido gaming."
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 14 — Servicios systemd user (quickshell + awww)
# ─────────────────────────────────────────────────────────────
install_user_service() {
	local fname="$1"
	local src="$REPO_DIR/systemd-user/$fname"
	local dst="$SYSTEMD_USER_DIR/$fname"
	if [ ! -f "$src" ]; then
		warn "Falta $src; se omite el servicio $fname."
		return 1
	fi
	link_file "$src" "$dst"
	if "$DRY_RUN"; then
		printf '  [dry-run] systemctl --user daemon-reload\n'
		printf '  [dry-run] systemctl --user enable %s\n' "${fname%.service}"
		return 0
	fi
	systemctl --user daemon-reload
	systemctl --user enable "${fname%.service}"
	ok "Servicio habilitado: ${fname%.service}"
}

step_servicios() {
	step_begin "Servicios systemd (usuario)" \
		"Instala y habilita quickshell.service y awww.service"

	install_user_service "quickshell.service" || true
	install_user_service "awww.service" || true

	echo
	if ! "$DRY_RUN" && "$INTERACTIVE"; then
		if confirm "¿Arrancar quickshell ahora? (si ya estás en una sesión, quizá prefieras reiniciar la sesión)"; then
			systemctl --user start quickshell.service || warn "No se pudo iniciar quickshell ahora."
		fi
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 15 — Symlinks de configuración (setup.sh)
# ─────────────────────────────────────────────────────────────
step_symlinks() {
	step_begin "Symlinks de configuración" \
		"Enlaza config del repo a ~/.config y ~/.local/share/applications (setup.sh)"
	if [ ! -f "$REPO_DIR/setup.sh" ]; then
		die "Falta setup.sh en el repo."
	fi
	if "$DRY_RUN"; then
		bash "$REPO_DIR/setup.sh" --dry-run
	else
		bash "$REPO_DIR/setup.sh"
	fi

	# Regenerar shortcuts.json con un reload de hyprland si está en sesión
	if command -v hyprctl >/dev/null 2>&1 && hyprctl activeworkspace >/dev/null 2>&1; then
		info "Recargando Hyprland para regenerar shortcuts.json..."
		run hyprctl reload
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 16 — SDDM (pregunta)
# ─────────────────────────────────────────────────────────────
step_sddm() {
	step_begin "SDDM — tema evergarden" \
		"Copia el tema a /usr/share/sddm/themes y escribe sddm.conf (requiere sudo)"

	if ! "$DO_SDDM"; then
		echo "  (saltado por --no-sddm)"
		return 0
	fi

	if ! "$INTERACTIVE"; then
		echo "  (modo no interactivo: se omite, usa --no-sddm para silenciar)"
		return 0
	fi

	if ! confirm "¿Instalar y configurar el tema SDDM evergarden?"; then
		warn "Omitido SDDM."
		return 0
	fi

	local theme_src="$REPO_DIR/sddm/evergarden"
	local theme_dst="/usr/share/sddm/themes/evergarden"
	if [ ! -d "$theme_src" ]; then
		warn "Falta $theme_src; se omite SDDM."
		return 0
	fi

	if "$DRY_RUN"; then
		printf '  [dry-run] sudo mkdir -p /usr/share/sddm/themes/evergarden\n'
		printf '  [dry-run] sudo cp -r %s/. %s/\n' "$theme_src" "$theme_dst"
		printf '  [dry-run] sudo cp %s/sddm.conf /etc/sddm.conf.d/10-hyprquickdots.conf\n' "$REPO_DIR"
	else
		sudo mkdir -p "$theme_dst"
		sudo cp -r "$theme_src/." "$theme_dst/"
		ok "Tema SDDM copiado a $theme_dst"

		# sddm.conf -> /etc/sddm.conf.d/ (sobrescribe, no pisa /etc/sddm.conf)
		if [ -f "$REPO_DIR/sddm.conf" ]; then
			sudo mkdir -p /etc/sddm.conf.d
			sudo cp "$REPO_DIR/sddm.conf" /etc/sddm.conf.d/10-hyprquickdots.conf
			ok "sddm.conf instalado en /etc/sddm.conf.d/10-hyprquickdots.conf"
		fi
	fi
}

# ─────────────────────────────────────────────────────────────
# Paso 17 — Post-install de usuario (chsh, git, node)
# ─────────────────────────────────────────────────────────────
step_postinstall() {
	step_begin "Post-install (cuenta de usuario)" \
		"chsh a fish, config git (opcional), node LTS con fnm, corepack"

	# Git identity (solo si no está configurado y hay interacción)
	if [ "$(git config --global user.name 2>/dev/null || echo "")" = "" ]; then
		if "$INTERACTIVE"; then
			if confirm "¿Configurar identidad de git ahora?"; then
				local gname gemail
				printf '    Nombre git: '; read -r gname
				printf '    Email git:  '; read -r gemail
				if [ -n "$gname" ]; then git config --global user.name "$gname"; fi
				if [ -n "$gemail" ]; then git config --global user.email "$gemail"; fi
				ok "git config actualizado"
			fi
		fi
	fi

	# Cambiar shell a fish (si fish está instalado)
	if command -v fish >/dev/null 2>&1; then
		if [ "$SHELL" != "/usr/bin/fish" ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/fish" ]; then
			if "$INTERACTIVE"; then
				if confirm "¿Cambiar la shell por defecto a fish (chsh)?"; then
					run chsh -s /usr/bin/fish
				fi
			else
				run chsh -s /usr/bin/fish
			fi
		else
			ok "fish ya es la shell por defecto"
		fi
	fi

	# node LTS con fnm (si fnm está)
	if command -v fnm >/dev/null 2>&1; then
		if "$INTERACTIVE"; then
			confirm "¿Instalar Node LTS con fnm + habilitar corepack (pnpm)?" && {
				run fnm install --lts
				run corepack enable
			}
		else
			run fnm install --lts
			run corepack enable
		fi
	fi
}

# ─────────────────────────────────────────────────────────────
# Resumen final + verificación
# ─────────────────────────────────────────────────────────────
summary() {
	echo
	echo "=========================================================================="
	echo "  RESUMEN DE LA INSTALACIÓN"
	echo "=========================================================================="
	echo
	info "Secciones procesadas:"
	if "$DO_MENU"; then
		local any=0
		for id in "${SECTION_ORDER[@]}"; do
			if [ "${SECTION_STATE[$id]}" = "1" ]; then
				printf '  - %s\n' "${SECTION_NAMES[$id]}"
				any=1
			fi
		done
		[ "$any" -eq 0 ] && warn "  (ninguna sección seleccionada)"
	else
		for id in "${SECTION_ORDER[@]}"; do
			printf '  - %s\n' "${SECTION_NAMES[$id]}"
		done
	fi

	echo
	info "Comandos de verificación:"
	echo "  # El shell corriendo"
	echo "  systemctl --user status quickshell"
	echo "  qs log                    # errores/avisos del shell"
	echo "  hyprctl reload            # regenera quickshell/shortcuts.json"
	echo
	info "Atajos clave:"
	echo "  SUPER+R     launcher       SUPER+B   quick access"
	echo "  SUPER+SHIFT+S  captura     SUPER+D   dictado (si instalaste el modelo o configuraste)"
	echo "  SUPER+A     app browser    SUPER+SPACE  …"
	echo
	local SHOW_DICT_HINT=false
	if "$DO_MENU"; then
		[ "${SECTION_STATE[dictado]:-1}" = "1" ] && SHOW_DICT_HINT=true
	else
		[ "$DO_WHISPER" = true ] && SHOW_DICT_HINT=true
	fi
	if "$SHOW_DICT_HINT" && [ -z "$(ls "$HOME/.local/share/dictation/models/"*.bin 2>/dev/null || true)" ]; then
		warn "No has descargado ningún modelo de whisper. Para el dictado:"
		echo "  curl -L -o ~/.local/share/dictation/models/ggml-medium-q8_0.bin \\"
		echo "    https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin"
	fi
	echo
	local SHOW_SDDM_HINT=false
	if "$DO_MENU"; then
		[ "${SECTION_STATE[sddm]:-1}" = "1" ] && SHOW_SDDM_HINT=true
	else
		[ "$DO_SDDM" = true ] && SHOW_SDDM_HINT=true
	fi
	if "$SHOW_SDDM_HINT" && [ -f /etc/sddm.conf.d/10-hyprquickdots.conf ]; then
		info "SDDM listo. Puedes probar el tema sin reiniciar todo:"
		echo "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/evergarden"
	fi
	echo
	if ! "$DRY_RUN"; then
		info "Para aplicar todo (shell, wallpapers, atajos) reinicia la sesión:"
		echo "  uwsm stop            # salir de la sesión actual"
	fi
	echo
	echo "=========================================================================="
}

# ─────────────────────────────────────────────────────────────
# Registro de secciones seleccionables (para --menu)
# Se registran ANTES de main(). Cada entrada:
#   register_section <id> "<nombre>" "<desc>" <func> [default=1]
# El enfoque: step_* ya genera su propio banner dinámico (step_begin).
# ─────────────────────────────────────────────────────────────
register_all_sections() {
	register_section fundamentales "Dependencias fundamentales" \
		"fish, uwsm, git, base-devel, portal Hyprland, pipewire, Hyprland, audio…" step_fundamentales 1
	register_section devtools "Herramientas de desarrollo" \
		"fnm, zoxide, neovim, lazygit, tree-sitter, fzf, ripgrep, fd, opencode" step_devtools 1
	register_section shellterminal "Shell, terminal y barra" \
		"kitty, zellij, starship y Nerd Fonts del sistema" step_shell_terminal 1
	register_section quickshell "Quickshell + entorno Qt" \
		"El shell + qt6 tools, temas Qt/GTK (adw-gtk3), papirus, unixodbc" step_quickshell 1
	register_section fuentes "Fuentes locales" \
		"Rubik a ~/.local/share/fonts + fc-cache" step_fuentes 1
	register_section fontconfig "Configuración de fuentes (Dota 2)" \
		"fontconfig/fonts.conf: Arial/Tahoma/Verdana" step_fontconfig 1
	register_section capturas "Capturas, OCR y color" \
		"hyprshot, grim, swappy, tesseract, hyprpicker" step_capturas 1
	register_section portapapeles "Portapapeles" \
		"cliphist + wl-clipboard" step_portapapeles 1
	register_section wallpaper "Wallpaper (awww)" \
		"awww (daemon en la sección de servicios)" step_wallpaper 1
	register_section sistema "Sistema, input y energía" \
		"hyprsunset, brightnessctl, lm_sensors, power-profiles-daemon" step_sistema 1
	register_section dictado "Dictado por voz (whisper)" \
		"whisper-cpp + ggml + elegir modelo" step_dictado 0
	register_section gaming "Gaming (opcional)" \
		"cachyos-gaming-meta + steam (MUY pesado)" step_gaming 0
	register_section servicios "Servicios systemd (usuario)" \
		"quickshell.service + awww.service" step_servicios 1
	register_section symlinks "Symlinks de configuración" \
		"setup.sh: enlaza config + aplicaciones" step_symlinks 1
	register_section sddm "SDDM — tema evergarden" \
		"Tema + /etc/sddm.conf.d (requiere sudo)" step_sddm 0
	register_section postinstall "Post-install (cuenta)" \
		"chsh a fish, git config, node LTS con fnm, corepack" step_postinstall 1
}

# ─────────────────────────────────────────────────────────────
# Menú de selección de secciones (interactivo)
# Permite marcar/desmarcar cada sección y luego instalar solo las marcadas.
# ─────────────────────────────────────────────────────────────
menu_select() {
	section "Selección de secciones" \
		"Marca con su número qué quieres instalar. Escribe 't' para todo, 'n' para nada, 'enter' para continuar."

	# Estado inicial: aplicar flags globales (--no-whisper/--no-sddm/--no-gaming)
	if [ "$DO_WHISPER" = false ]; then SECTION_STATE[dictado]=0; fi
	if [ "$DO_SDDM" = false ]; then SECTION_STATE[sddm]=0; fi
	if [ "$DO_GAMING" = false ]; then SECTION_STATE[gaming]=0; fi

	local choice=""
	while true; do
		echo
		local idx=1
		for id in "${SECTION_ORDER[@]}"; do
			local mark="[ ]"
			[ "${SECTION_STATE[$id]}" = "1" ] && mark="[x]"
			printf '  %2d  %s  %s\n' "$idx" "$mark" "${SECTION_NAMES[$id]}"
			idx=$((idx + 1))
		done
		echo
		printf '  t = todo · n = nada · número = alternar · enter = instalar lo marcado\n'
		printf '  > '
		if ! read -r choice; then
			choice=""
		fi
		case "$choice" in
			"") break ;;
			t|T|a|A|s|S) for id in "${SECTION_ORDER[@]}"; do SECTION_STATE["$id"]=1; done ;;
			n|N|nada)     for id in "${SECTION_ORDER[@]}"; do SECTION_STATE["$id"]=0; done ;;
			*) if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#SECTION_ORDER[@]}" ]; then
				 local sel_id="${SECTION_ORDER[$((choice - 1))]}"
				 if [ "${SECTION_STATE[$sel_id]}" = "1" ]; then SECTION_STATE["$sel_id"]=0; else SECTION_STATE["$sel_id"]=1; fi
			   else
				 echo "    Entrada inválida."
			   fi ;;
		esac
	done

	echo
	echo "Se instalarán las siguientes secciones:"
	local n=0
	for id in "${SECTION_ORDER[@]}"; do
		if [ "${SECTION_STATE[$id]}" = "1" ]; then
			printf '  - %s\n' "${SECTION_NAMES[$id]}"
			n=$((n + 1))
		fi
	done
	if [ "$n" -eq 0 ]; then
		warn "No seleccionaste ninguna sección."
		if ! "$DRY_RUN" && "$INTERACTIVE"; then
			confirm "¿Continuar igualmente (sin instalar nada)?" || die "Cancelado."
		fi
	fi
	STEP_TOTAL="$n"
}

# ─────────────────────────────────────────────────────────────
# Ejecuta una sección si está marcada; en modo sin menú, todas.
# ─────────────────────────────────────────────────────────────
run_section() {
	local id="$1"
	if "$DO_MENU"; then
		[ "${SECTION_STATE[$id]}" = "1" ] || return 0
	fi
	"${SECTION_FUNC[$id]}"
}

# ─────────────────────────────────────────────────────────────
# Flujo principal
# ─────────────────────────────────────────────────────────────
main() {
	echo
	info "Instalador de HyprQuickDots — CachyOS/Arch"
	if "$DRY_RUN"; then
		warn "Modo --dry-run: no se cambiará nada, solo se muestra lo que se haría."
	fi
	if ! "$INTERACTIVE"; then
		warn "Modo no interactivo: se instala todo salvo gaming/SDDM."
	fi
	echo

	preflight

	register_all_sections

	if "$DO_MENU"; then
		if ! "$INTERACTIVE"; then
			die "--menu requiere modo interactivo (quita --no-interactive)."
		fi
		menu_select
		[ "$STEP_TOTAL" -eq 0 ] && STEP_TOTAL="${#SECTION_ORDER[@]}"
	else
		STEP_TOTAL="${#SECTION_ORDER[@]}"
	fi

	step_reset "$STEP_TOTAL"
	run_section fundamentales
	run_section devtools
	run_section shellterminal
	run_section quickshell
	run_section fuentes
	run_section fontconfig
	run_section capturas
	run_section portapapeles
	run_section wallpaper
	run_section sistema
	run_section dictado
	run_section gaming
	run_section servicios
	run_section symlinks
	run_section sddm
	run_section postinstall
	summary
}

main "$@"
