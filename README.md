# HyprQuickDots

Dotfiles personales de una instalación Hyprland + Quickshell sobre **CachyOS** (Arch-based), gestionada con **uwsm** como sesión. El shell completo (barra, launcher, quick access, dictado, screenshot, wallpaper, lock, settings) está hecho con Quickshell/QML.

Este repositorio **no es un repo git** — se edita en vivo y todo está **symlinkeado** a `~/.config`.

---

## Instalación

### Primera instalación desde cero (máquina limpia con solo Hyprland)

Cuando instalas el sistema desde cero, **no tienes** ni este repo ni los
instaladores todavía. Tú mismo abres Hyprland, pero aun falta todo lo demás.
El flujo es:

**1. Obtén el repo** (eliges UNA de estas):

```bash
# Opción A — desde GitHub/GitLab (tienes que haberlo subido antes)
sudo pacman -S --needed git base-devel        # lo mínimo para clonar
git clone <URL-de-tu-repositorio> ~/Repos/HyprQuickDots

# Opción B — desde un USB / disco externo (copia la carpeta completa, con install.sh)
mkdir -p ~/Repos
cp -r /ruta/al/disco/HyprQuickDots ~/Repos/
```

**2. Entra y ejecuta el instalador:**

```bash
cd ~/Repos/HyprQuickDots
./install.sh                 # interactivo: elige secciones con --menu
# o el respaldo directo:
./install-cli.sh
```

**3. (Opcional)** Si te falta el bloque `archlinux-appstream-data` o quieres
asegurarte de que los repos CachyOS están actualizados antes de instalar:

```bash
sudo pacman -Syu
```

No necesitas instalar nada más antes: el instalador se encarga de `hyprland`,
`pipewire`, `quickshell`, fuentes, dictado, wallpaper, servicios y SDDM,
**todo desde los repos oficiales de pacman/CachyOS** (sin AUR).

Puedes previsualizar todo sin tocar nada con `./install.sh --dry-run`
(o `./install-cli.sh --dry-run`).

### Requisitos

- **CachyOS** o cualquier Arch-based con `pacman` (repos oficiales, sin AUR).
- Conexión a internet.
- GPU con soporte **Vulkan** recomendada (para el dictado con whisper y widgets AMD).
- Ejecutar como usuario normal (el script usa `sudo` de forma puntual).

### Rápido (todo automático)

```bash
git clone <origen> HyprQuickDots
cd HyprQuickDots
./install.sh
```

El instalador es **interactivo y por secciones**: pregunta antes de cada paso pesado (gaming, SDDM, dictado/modelo, etc.) y te muestra en todo momento qué está instalando y para qué sirve.

### Opciones del instalador

```bash
./install.sh                    # flujo completo e interactivo
./install.sh --menu             # elige qué secciones instalar (menú interactivo)
./install.sh --no-whisper       # salta la sección de dictado (modelo whisper)
./install.sh --no-sddm          # no toca el tema SDDM
./install.sh --no-gaming        # no pregunta por cachyos-gaming-meta/steam
./install.sh --no-interactive   # sin preguntas (instala todo lo no opcional)
./install.sh --dry-run          # solo muestra lo que haría
./install.sh --help
```

### Selección por secciones (`--menu`)

En lugar de instalar todo en bloque, `--menu` muestra una lista numerada de
secciones con su estado `[x]`/`[ ]` y te deja marcar/desmarcar cuáles instalar:

```
  1  [x]  Dependencias fundamentales
  2  [x]  Herramientas de desarrollo
  ...
 11  [ ]  Dictado por voz (whisper)      ← desmarcada por defecto
 12  [ ]  Gaming (opcional)              ← desmarcada por defecto
 15  [ ]  SDDM — tema evergarden         ← desmarcada por defecto

  t = todo · n = nada · número = alternar · enter = instalar lo marcado
```

- Escribe un **número** para alternar esa sección, **t** para marcar todas,
  **n** para desmarcar todas, y **enter** para instalar solo lo seleccionado.
- Las secciones pesadas (dictado, gaming, SDDM) vienen desmarcadas por defecto;
  márcalas si las quieres.

### Instalador CLI de respaldo (`install-cli.sh`)

¿Prefieres un instalador simple y directo de terminal, sin interfaz? O si
`install.sh` falla, usa el respaldo. Hace lo mismo pero **en bloque**, fiel a
los clásicos comandos `pacman` del tutorial original:

```bash
./install-cli.sh                   # instala todo (incluye gaming y SDDM)
./install-cli.sh --no-whisper      # sin whisper / modelo
./install-cli.sh --no-gaming       # sin cachyos-gaming-meta / steam
./install-cli.sh --no-sddm         # sin tema SDDM
./install-cli.sh --dry-run         # solo muestra los comandos
./install-cli.sh --help
```

Diferencias con `install.sh`:
- No tiene menú ni preguntas: instala **todo** con un solo `pacman -S --needed`.
- Por defecto sí instala gaming y SDDM (usa `--no-gaming` / `--no-sddm` para quitarlos).
- El modelo de whisper se descarga automático (medium-q8); si lo quieres más ligero usa `install.sh`.

### Qué hace cada sección

| # | Sección | Paquetes / acción |
|---|---------|-------------------|
| 1 | **Preflight** | Detecta distro, comprueba root, sudo, conexión |
| 2 | **Fundamentales** | `fish uwsm git base-devel xdg-desktop-portal-hyprland wl-clipboard curl python` |
| 3 | **Dev tools** | `fnm zoxide neovim lazygit tree-sitter-cli fzf ripgrep fd opencode` |
| 4 | **Shell, terminal, barra** | `kitty zellij starship ttf-nerd-fonts-symbols ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd` |
| 5 | **Quickshell + Qt** | `quickshell` + `qt6-tools qt6-declarative qt6ct adw-gtk-theme papirus-icon-theme unixodbc` |
| 6 | **Fuentes** | Extrae `fonts/Rubik.zip` (si existe) a `~/.local/share/fonts` + `fc-cache -fv` |
| 7 | **Fontconfig (Dota 2)** | Copia `fontconfig/fonts.conf` (Arial→Liberation Sans, Tahoma/Verdana→DejaVu Sans) |
| 8 | **Capturas, OCR, color** | `hyprshot grim swappy tesseract tesseract-data-spa tesseract-data-eng hyprpicker` |
| 9 | **Portapapeles** | `cliphist wl-clipboard` |
| 10 | **Wallpaper** | `awww` + habilita `awww.service` |
| 11 | **Sistema** | `hyprsunset brightnessctl lm_sensors power-profiles-daemon` |
| 12 | **Dictado (whisper)** | `whisper-cpp ggml ggml-vulkan vulkan-icd-loader ffmpeg` + elección **interactiva del modelo** (`ggml-cpu` lo provee `ggml`) |
| 13 | **Gaming (opcional)** | `cachyos-gaming-meta steam` — pregunta antes (varios GB) |
| 14 | **Servicios systemd** | Instala y habilita `quickshell.service` + `awww.service` |
| 15 | **Symlinks** | Ejecuta `setup.sh` (enlaza config + aplicaciones) |
| 16 | **SDDM** | Copia el tema `evergarden` + escribe `/etc/sddm.conf.d/10-hyprquickdots.conf` |
| 17 | **Post-install** | `chsh` a fish, identidad git (opcional), `fnm install --lts`, `corepack enable` |

> El listado completo de paquetes (por sección, con el motivo de instalación
> explícito/dependencia y comandos para instalar a mano) está en
> [`PACKAGES.md`](PACKAGES.md). Ahí también está la tabla de las
> **dependencias runtime** que el shell comprueba al arrancar
> (sección → binarios → comando de instalación).

---

## Post-instalación

Recarga la configuración y comprueba que todo esté vivo:

```bash
# Servicios de usuario
systemctl --user status quickshell
systemctl --user status awww

# Shell en marcha: logs y errores
qs log

# Regenera quickshell/shortcuts.json con los atajos reales
hyprctl reload
```

Para que el shell y todo el entorno tomen efecto, reinicia la sesión:

```bash
uwsm stop
```

### SDDM (tema evergarden)

El instalador copia el tema a `/usr/share/sddm/themes/evergarden` y escribe
`/etc/sddm.conf.d/10-hyprquickdots.conf` (`[Theme] Current=evergarden`, autologin a `hyprland`).

Puedes probar el tema sin reiniciar:

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/evergarden
```

> **Nota**: el fondo del SDDM es una imagen **estática ya desenfocada**
> (`sddm/evergarden/wallpaper-blur.jpg`), porque el usuario `sddm` no puede leer
> `~/.cache/awww` ni `~/Wallpapers`. Cuando cambies el wallpaper, regenérala:
> `magick ~/Wallpapers/<fondo> -blur 0x24 -brightness-contrast -10x-10 -quality 82 sddm/evergarden/wallpaper-blur.jpg`
> y vuelve a copiarla con `./setup.sh --sddm` (o `sudo cp -r`).

### Atajos principales

| Atajo | Acción |
|---|---|
| `SUPER+R` | Launcher |
| `SUPER+B` | Quick Access (panel de Android) |
| `SUPER+SHIFT+S` | Captura de pantalla |
| `SUPER+D` | Dictado por voz (si se instaló el modelo) |
| `SUPER+A` | App Browser (navegador de apps por categorías) |
| `SUPER+SPACE` | … (ver `Atajos` dentro de la Configuración del sistema) |

El buscador de atajos (Configuración → **Atajos**) siempre muestra los binds **reales** porque se regenera desde `shortcuts.lua` en cada `hyprctl reload`.

---

## Dictado por voz (whisper)

Detalles completos en [`tutorial/dictado.md`](tutorial/dictado.md). Resumen:

- **Paquetes**: `whisper-cpp ggml ggml-vulkan vulkan-icd-loader ffmpeg`. (`ggml-cpu` no es un paquete aparte: lo **provee** `ggml`.)
- **IMPORTANTE** — En `ggml` 0.20+ los backends viven en `/usr/lib/ggml/`. `ggml` ya trae el backend CPU, pero el de **GPU va en `ggml-vulkan`** (`libggml-vulkan.so`). Sin ese paquete `whisper-cli` funciona, pero cae a CPU y va mucho más lento aunque tengas GPU.
- **Modelo** (interactivo en el instalador, o manual):

```bash
mkdir -p ~/.local/share/dictation/models
curl -L -o ~/.local/share/dictation/models/ggml-medium-q8_0.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin
```

  Cambia la ruta en `quickshell/dictate.json` → `modelPath` si usas otro modelo/idioma.

- El pegado automático usa `hyprctl dispatch 'hl.dsp.send_shortcut(...)'` (Hyprland ≥ 0.56) — **no** requiere `ydotool`/`wtype`.

---

## Arquitectura (resumen)

- **Hyprland** — config Lua (`hypr/hyprland.lua`) usando el DSL `hl.*`, dividida en `hypr/modules/*.lua`. `hypr/modules/shortcuts.lua` es la fuente de verdad de los keybinds (todo pasa por `shortcuts.bind` para que aparezcan en el buscador de atajos).
- **uwsm** — gestor de sesión; exporta las variables de entorno de `uwsm/env` (`GDK_BACKEND`, `QT_QPA_PLATFORM`, etc.).
- **Quickshell** — el shell completo (`quickshell/shell.qml`): barra, launcher, quick access, screenshot, clipboard, lock, idle, wallpaper, polkit, switcher y settings. Se controla por IPC (`qs ipc call <target> <action>`) y arranca como servicio systemd (`quickshell.service`).
- **Servicios systemd user** — `quickshell.service` y `awww.service` viven en `systemd-user/` y arrancan con `graphical-session.target`.

Ver `AGENTS.md` para la documentación arquitectónica extensa (widgets, dictado, night-light, bluetooth, etc.).

---

## Troubleshooting

| Síntoma | Causa / solución |
|---|---|
| `whisper-cli` hace **abort** al transcribir | Falta el backend de ggml. Reinstala `ggml` (CPU) y/o `ggml-vulkan` (GPU) — ver [dictado](tutorial/dictado.md) |
| El dictado va lento | Sin GPU cae a CPU: comprueba `vulkaninfo --summary \| grep -A3 "GPU[0-9]"` **y** `ls -l /usr/lib/ggml/libggml-vulkan.so` |
| `qs` / `quickshell` no en PATH | Reinicia la sesión. Confirma que el paquete de repos instaló `/usr/bin/qs` |
| La barra no aparece / QS no arranca | `systemctl --user status quickshell` y `qs log` |
| El Atajos no se actualiza | `hyprctl reload` (regenera `quickshell/shortcuts.json`) |
| Fuentes raras en juegos (p. ej. Dota 2) | El instalador ya puso `fontconfig/fonts.conf`; si no, cópialo y `fc-cache -fv` |
| Muchas llamadas de `systemctl --user restart quickshell` no aplican cambios de QML | No hace falta: `hyprctl reload` recarga binds; para QML usa `systemctl --user restart quickshell` |

---

## License / Nota

Dotfiles personales. Comentarios y textos de UI en español. Sin `git` — los cambios aquí son **vivos** (symlinks a `~/.config`).
