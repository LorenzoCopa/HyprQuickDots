# Dictado por voz (whisper.cpp) — instalación desde cero

Guía para que el dictado con SUPER+D funcione en una instalación limpia.
Todo lo de config ya vive en el repo; aquí solo hace falta instalar binarios
y descargar el modelo.

## 1. Dependencias

Las más son del repositorio principal de Arch (packages son de 2026):

```bash
sudo pacman -S whisper-cpp ggml ggml-cpu ggml-vulkan vulkan-icd-loader ffmpeg wl-clipboard
```

> **OJO con `ggml` 0.20**: desde esa versión Arch/CachyOS **separó los backends en
> paquetes propios**. El paquete base `ggml` solo instala `libggml-base` y
> `libggml` — **sin los plugins de backend**, que ahora viven en `/usr/lib/ggml/`
> y los aportan `ggml-cpu` (libggml-cpu-*.so) y `ggml-vulkan`
> (libggml-vulkan.so). Si solo instalas `ggml`, `whisper-cli` hace abort
> (`ggml_abort` en `ggml_backend_dev_backend_reg`) justo al iniciar el modelo y
> el dictado no transcribe. **`ggml-cpu` y `ggml-vulkan` son obligatorios.**

Si `whisper-cpp`/`ggml` no están en tu mirror, vienen de:
- `whisper-cpp` → AUR (paquete `whisper-cpp` o el `whisper.cpp-bin` de flathub/otro)
- `ggml`/`ggml-cpu`/`ggml-vulkan` → AUR (necesarios con soporte Vulkan, p. ej.
  `ggml-rosa`/`ggml` con la variante `vulkan`; asegúrate de que el paquete
  incluya los plugins en `/usr/lib/ggml/`)
- `vulkan-icd-loader` → extra

Cosas que **ya** se asumen del entorno y no hay que re-instalar:
- `pw-record` (parte de `pipewire`)
- `hyprctl` (parte de Hyprland)
- El pipeline de portapapeles (`wl-copy` viene con `wl-clipboard`)

## 2. Verificar GPU Vulkan (opcional pero recomendado)

```bash
vulkaninfo --summary | grep -A3 "GPU[0-9]"
```

Debe listar la GPU real (p. ej. AMD RX 5600 XT). Sin dispositivo Vulkan,
whisper-cli cae a CPU y el dictado va notablemente más lento.

## 3. Descargar el modelo

El modelo se guarda en `~/.local/share/dictation/models/` (default de
`dictate.json:modelPath`). El del setup actual es el medium cuantizado q8:

```bash
mkdir -p ~/.local/share/dictation/models
curl -L -o ~/.local/share/dictation/models/ggml-medium-q8_0.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin
```

> ~786 MB. Si se quiere más veloz: `ggml-small-q8_0.bin` (~264 MB) o, con el
> mejor equilibrio velocidad/precisión, `ggml-large-v3-turbo-q5_0.bin`
> (~574 MB, el destilado turbo, más rápido y preciso que medium).
> Luego cambiar la ruta en `quickshell/dictate.json` → `modelPath` (o usar el
> apartado "Dictado" de Configuración, que permite activar modelos instalados
> y descargarlos desde la propia interfaz).

## 4. Probar el pipeline solo

Graba y transcribe en un solo paso (sin Quickshell):

```bash
pw-record --rate 16000 --channels 1 /tmp/dict.wav
# Ctrl+C cuando termines de hablar

ffmpeg -y -v error -i /tmp/dict.wav \
  -af 'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.8,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.5,areverse' \
  /tmp/dict-trim.wav

whisper-cli -m ~/.local/share/dictation/models/ggml-medium-q8_0.bin \
  -l es -t 4 -nt -np /tmp/dict-trim.wav
```

Si imprime tu frase, todo el backend está bien y el problema sería de
Quickshell, no de instalación.

## 5. Verificación en vivo

- Recargar Quickshell después de instalar: `systemctl --user restart quickshell`
- El bind `SUPER+D` dispara `qs ipc call dictation toggle` (definido en
  `hypr/modules/quickshell/dictation.lua`, que `hyprland.lua` carga).
- Estado del OSD: `qs log` busca errores de `whisper-cli`/`pw-record`.

## 6. Troubleshooting

- **`whisper-cli` crashea (abort) al transcribir**: suele verse en gdb como
  `ggml_backend_dev_backend_reg` → `ggml_abort`, y al ejecutar `whisper-cli`
  a mano sale repetido `ggml_backend_load_best: search path /usr/lib/ggml does
  not exist`. Es que falta el backend: instala `ggml-cpu` (y `ggml-vulkan` para
  GPU) — ver nota de la sección 1.
- **El dictado va lento / cae a CPU**: verificar GPU Vulkan con
  `vulkaninfo --summary | grep -A3 "GPU[0-9]"`; sin dispositivo Vulkan,
  `whisper-cli` usa CPU y tarda bastante más.

## Notas

- El pegado automático (`pasteFocused: true`) usa
  `hyprctl dispatch 'hl.dsp.send_shortcut({...})'` de Hyprland 0.56 — **no**
  necesita `ydotool`/`wtype`. Si migraras a una versión pre-0.55, ese comando
  habría que volver a la sintaxis vieja `sendshortcut 'CTRL,V,'`.
- El idioma por defecto es `es` (`dictate.json:lang`).
- El texto se copia SIEMPRE al portapapeles (cliphist) aunque no se inserte.