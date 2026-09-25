# PACKAGES.md — Listado de paquetes por sección

Listado de **todos** los paquetes que usa este repo (HyprQuickDots), organizado
por las secciones del instalador. Sirve para:

- saber **qué instala** `install.sh` / `install-cli.sh` y para qué sirve cada
  paquete,
- instalar **a mano** si no quieres usar el instalador (hay un comando
  `pacman` por sección al final),
- distinguir lo que **instalas tú explícitamente** de lo que **trae el sistema**
  como dependencia (columna *origen*).

> **Origen** = motivo de instalación en esta máquina (pacman `Motivo de la
> instalación`). Un paquete marcado como *Dependencia* llegó solo al instalar
> otro; el instalador igualmente lo lista explícitamente. Los paquetes que
> **no** están en el instalador pero que el código necesita se explican en
> [Obviados (los trae el sistema)](#obviados-los-trae-el-sistema).

---

## 1. Dependencias fundamentales

| Paquete | Para qué | Origen |
|---|---|---|
| `fish` | Shell por defecto (config en `fish/`) | Explícito |
| `uwsm` | Gestor de sesión Wayland (arranca el entorno de Hyprland) | Explícito |
| `git` | Clonar/gestión del repo | Explícito |
| `base-devel` | Toolchain base para builds | Explícito |
| `xdg-desktop-portal-hyprland` | Portal del escritorio (capturas, theme sync) | Explícito |
| `wl-clipboard` | `wl-copy` / `wl-paste` (portapapeles Wayland, cliphist store) | Explícito |
| `curl` | Descargas (modelos whisper, IP del clima) | Dependencia |
| `python` | Daemon python de la luz nocturna (`shell.qml`) | Explícito |
| `unzip` | Extraer fuentes locales (Rubik.zip) | Explícito |
| `hyprland` | El compositor (config Lua en `hypr/`) | Explícito |
| `pipewire` | Núcleo de audio | Dependencia |
| `pipewire-pulse` | Compatibilidad PulseAudio | Explícito |
| `pipewire-alsa` | Salida ALSA vía PipeWire | Explícito |
| `wireplumber` | Gestión de sesión/volúmenes (`wpctl`) | Explícito |
| `playerctl` | Controles multimedia (teclas XF86, `MediaPanel`) | Explícito |
| `bluez` | Pila Bluetooth | Explícito |
| `bluez-utils` | `bluetoothctl` (vincular dispositivos) | Explícito |
| `networkmanager` | Red (widget de red del QuickAccess) | Explícito |
| `pam` | Autenticación del lock de Quickshell (`lock/pam/`) | Dependencia |

## 2. Herramientas de desarrollo

| Paquete | Para qué | Origen |
|---|---|---|
| `fnm` | Gestor de Node (LTS + corepack/pnpm) | Explícito |
| `zoxide` | `cd` inteligente (fish lo usa) | Explícito |
| `neovim` | Editor | Explícito |
| `lazygit` | Git en TUI | Explícito |
| `tree-sitter-cli` | Parsers de neovim | Explícito |
| `fzf` | Búsqueda difusa | Explícito |
| `ripgrep` | Búsqueda en el código | Explícito |
| `fd` | Alternativa a `find` | Dependencia |
| `opencode` | El asistente con el que editas este repo | Explícito |

## 3. Shell, terminal y fuentes

| Paquete | Para qué | Origen |
|---|---|---|
| `kitty` | Terminal por defecto (config en `kitty/`) | Explícito |
| `zellij` | Multiplexor (config en `zellij/`) | Explícito |
| `starship` | Prompt de fish (config única `starship.toml`) | Explícito |
| `ttf-nerd-fonts-symbols` | Glifos Nerd Font / Material Design Icons del shell | Explícito |
| `ttf-iosevkaterm-nerd` | Fuente del shell/terminal | Explícito |
| `ttf-jetbrains-mono-nerd` | Fuente del editor/código | Explícito |

## 4. Quickshell + entorno Qt (núcleo)

| Paquete | Para qué | Origen |
|---|---|---|
| `quickshell` | El shell completo (barra, launcher, quickaccess, wallpaper, lock, settings…) | Explícito |
| `qt6-tools` | Herramientas Qt 6 | Explícito |
| `qt6-declarative` | QML/QtQuick (el motor del shell) | Dependencia |
| `qt6ct` | Configuración Qt (apariencia) | Explícito |
| `adw-gtk-theme` | Temas GTK `adw-gtk3` / `adw-gtk3-dark` de la sección Tema (`scripts/set-theme.sh`) | Explícito |
| `papirus-icon-theme` | Iconos de las apps (launcher, AppBrowser) | Explícito |
| `unixodbc` | ODBC (requisito de quickshell/Qt) | Explícito |

## 5. Capturas, OCR y color

| Paquete | Para qué | Origen |
|---|---|---|
| `hyprshot` | Captura de pantalla (menú de captura de Quickshell). **Trae `jq` como dependencia** | Explícito |
| `grim` | Captura por output (fondo del lock screen) | Dependencia |
| `swappy` | Anotar/editar la captura | Explícito |
| `tesseract` + `tesseract-data-spa` + `tesseract-data-eng` | OCR de la captura (español+inglés) | Explícito |
| `hyprpicker` | Selector de color (SUPER+SHIFT+P) | Explícito |

## 6. Portapapeles

| Paquete | Para qué | Origen |
|---|---|---|
| `cliphist` | Historial del portapapeles (panel y búsqueda) | Explícito |
| `wl-clipboard` | Base Wayland del portapapeles (`wl-paste --watch cliphist store`) | Explícito |

## 7. Wallpaper

| Paquete | Para qué | Origen |
|---|---|---|
| `awww` | Daemon de fondos de pantalla (cambia el wallpaper desde el QuickAccess; `awww.service`) | Explícito |

## 8. Sistema, input y energía

| Paquete | Para qué | Origen |
|---|---|---|
| `hyprsunset` | Luz nocturna (temperatura de color, tile del QuickAccess + sección) | Explícito |
| `brightnessctl` | Brillo del backlight (OSD de brillo). **Nota: hoy no está instalado en esta máquina; el código cae a escribir `/sys` directamente** | No instalado (el instalador lo incluye) |
| `lm_sensors` | `sensors` (widgets Sistema/GPU del QuickAccess) | Dependencia |
| `power-profiles-daemon` | Perfil de energía (tile "Perf/Equi/Ahorro" del QuickAccess + sección Energía, vía `powerprofilesctl`). **Trae `upower` como dependencia** | Explícito |

## 9. Dictado por voz (whisper) — opcional

| Paquete | Para qué | Origen |
|---|---|---|
| `whisper-cpp` | `whisper-cli` (transcripción) | Explícito |
| `ggml` | Backend base de whisper.cpp | Explícito |
| `ggml-cpu` | Backend CPU (obligatorio en ggml ≥0.20) | Explícito |
| `ggml-vulkan` | Backend GPU Vulkan (obligatorio en ggml ≥0.20) | Explícito |
| `vulkan-icd-loader` | Carga de drivers Vulkan | Dependencia |
| `ffmpeg` | Recorte de silencio del WAV grabado (dictado/voicecmd) | Dependencia |

> El **modelo** de whisper NO es un paquete: se descarga de Hugging Face a
> `~/.local/share/dictation/models/` (el instalador lo elige interactivamente).

## 10. Gaming — opcional

| Paquete | Para qué | Origen |
|---|---|---|
| `cachyos-gaming-meta` | Meta-paquete gaming CachyOS (**trae `vulkan-tools`**) | Explícito |
| `steam` | Steam | Explícito |

---

## Runtime — verificador de dependencias (quickshell/deps)

El shell comprueba al arrancar (y bajo demanda con `qs ipc call deps check`, o
con el botón **Reintentar** del aviso) que existen los binarios de cada
sección. Si falta alguno, `DepsToast` muestra un aviso con el comando de
instalación exacto en lugar de fallar en silencio.

La **fuente de verdad** de la lista es `quickshell/deps/DependencyCheck.qml`
— mantener en sync con esta tabla y con `install.sh`.

| Sección | Binarios que comprueba | Comando de instalación |
|---|---|---|
| Capturas de pantalla | `hyprshot`, `grim`, `slurp` | `sudo pacman -S hyprshot grim slurp` |
| Selector de color | `hyprpicker` | `sudo pacman -S hyprpicker` |
| Portapapeles | `cliphist`, `wl-copy` | `sudo pacman -S cliphist wl-clipboard` |
| Fondo de pantalla | `awww` | `sudo pacman -S awww` |
| Luz nocturna | `hyprsunset`, `python3` (daemon) | `sudo pacman -S hyprsunset python` |
| Teclas multimedia | `playerctl` | `sudo pacman -S playerctl` |
| Modo de energía | `powerprofilesctl` | `sudo pacman -S power-profiles-daemon` |
| Bluetooth | `bluetoothctl` | `sudo pacman -S bluez-utils` |
| Red | `nmcli` | `sudo pacman -S networkmanager` |
| Dictado / comandos de voz | `whisper-cli`, `pw-record`, `ffmpeg` | `sudo pacman -S whisper-cpp pipewire-audio ffmpeg` |
| Widgets Sistema/GPU | `sensors` | `sudo pacman -S lm_sensors` |
| Núcleo (Hyprland) | `hyprland` | `sudo pacman -S hyprland` |

> Excepción deliberada: `brightnessctl` NO está en la lista aunque el
> instalador lo incluya — el brillo tiene fallback a `/sys` en `shell.qml`,
> así que su ausencia no rompe la feature y no debe mostrar el aviso.

---

## Obviados (los trae el sistema)

El código de Quickshell usa estos binarios, pero **no hace falta añadirlos al
instalador**: ya llegan como dependencia de paquetes que sí se instalan.

| Binario / paquete | Lo usa | Llega con |
|---|---|---|
| `jq` (paquete `jq`) | Captura de **ventana/activa** (`hyprctl activewindow -j \| jq`), widgets Sistema/GPU, "Comprobar repo" del dictado | `hyprshot` (lo exige) |
| `pw-record` / `pw-play` (paquete `pipewire-audio`) | Grabación y sonidos del dictado/voicecmd | `pipewire-pulse` + `pipewire-alsa` (lo exigen) |
| `upower` | Battería: "tiempo restante" (el % viene de `/sys`) | `power-profiles-daemon` (lo exige) |
| Portal GTK (`xdg-desktop-portal-gtk`) | Sync del tema de apps Qt (`QT_QPA_PLATFORMTHEME=xdgdesktopportal` en `uwsm/env` lee gsettings vía portal) | `gtk4` (lo exige; cualquier app GTK lo trae) |
| `vulkaninfo` (paquete `vulkan-tools`) | Solo verificar GPU para el dictado (es un aviso, no bloquea) | `cachyos-gaming-meta` (solo si instalas gaming) |

---

## Instalación manual (sin el instalador)

Cada sección como un `pacman -S --needed`:

```bash
# 1. Fundamentales
sudo pacman -S --needed fish uwsm git base-devel xdg-desktop-portal-hyprland \
  wl-clipboard curl python unzip hyprland pipewire pipewire-pulse pipewire-alsa \
  wireplumber playerctl bluez bluez-utils networkmanager pam

# 2. Dev tools
sudo pacman -S --needed fnm zoxide neovim lazygit tree-sitter-cli fzf ripgrep fd opencode

# 3. Shell, terminal y fuentes
sudo pacman -S --needed kitty zellij starship ttf-nerd-fonts-symbols \
  ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd

# 4. Quickshell + Qt
sudo pacman -S --needed quickshell qt6-tools qt6-declarative qt6ct adw-gtk-theme \
  papirus-icon-theme unixodbc

# 5. Capturas, OCR y color
sudo pacman -S --needed hyprshot grim swappy tesseract tesseract-data-spa \
  tesseract-data-eng hyprpicker

# 6. Portapapeles
sudo pacman -S --needed cliphist wl-clipboard

# 7. Wallpaper
sudo pacman -S --needed awww

# 8. Sistema, input y energía
sudo pacman -S --needed hyprsunset brightnessctl lm_sensors power-profiles-daemon

# 9. Dictado (opcional)
sudo pacman -S --needed whisper-cpp ggml ggml-cpu ggml-vulkan vulkan-icd-loader ffmpeg

# 10. Gaming (opcional)
sudo pacman -S --needed cachyos-gaming-meta steam
```

Después: `./setup.sh` (symlinks), `systemctl --user enable --now quickshell awww`
y reiniciar la sesión (`uwsm stop`). Ver `README.md`.

## Verificación

```bash
systemctl --user status quickshell
systemctl --user status awww
qs log
hyprctl reload     # regenera quickshell/shortcuts.json
```