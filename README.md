# Krita AI Plugins & ComfyUI Updater

Un script ligero y multiplataforma (Linux, Windows y macOS) para comprobar, descargar y mantener actualizados automáticamente los plugins de Inteligencia Artificial para **Krita**, junto con el backend de **ComfyUI** y sus nodos personalizados (`custom_nodes`). Incluye integración directa con el lanzador de aplicaciones de **KDE Plasma**.

Escrito en Python 3 utilizando únicamente la librería estándar (sin dependencias externas).

---

## Plugins soportados

1. **[Krita AI Diffusion](https://github.com/Acly/krita-ai-diffusion)** (`Acly/krita-ai-diffusion`)
   Generación de imágenes, inpainting, outpainting, escalado y control en tiempo real dentro de Krita.
2. **[Krita Vision Tools](https://github.com/Acly/krita-vision-tools)** (`Acly/krita-vision-tools`)
   Segmentación inteligente de objetos, eliminación de fondos y herramientas de selección asistida por IA.

---

## Características

- 🔍 **Detección inteligente de versión de Krita (Krita 5 / Qt5 vs Krita 6 / Qt6)**:
  - Detecta automáticamente qué versión de Krita tienes instalada (`krita --version`).
  - Si tienes **Krita 6.x** (ej. `6.0.4`), selecciona automáticamente las versiones compiladas para Qt6 (`v1.54.0-pre`+ en *AI Diffusion* y `v3.0.0-pre`+ en *Vision Tools*), evitando hacer *downgrade* accidental a los releases de Krita 5 (`v1.53.0` / `v2.2.0`).
  - Incluye corrección automática para el bug [Acly/krita-ai-diffusion#2648](https://github.com/Acly/krita-ai-diffusion/issues/2648), evitando que `v1.54.0-pre` muestre un falso aviso de actualización hacia `1.53.0` dentro del panel de Krita.
- 📦 **Sin dependencias externas**: Funciona con cualquier instalación estándar de Python 3 (`urllib`, `zipfile`, `pathlib`, etc.).
- 🚀 **Integración con KDE Plasma**: Incluye instalador (`install.sh`) y lanzador `.desktop` (**Update Krita AI Tools**) con icono nativo de Krita, notificaciones de escritorio (`notify-send`) y ejecución en `konsole`.
- 🛡️ **Actualización segura con respaldo**:
  - Detecta si **Krita** está en ejecución antes de modificar archivos y espera a que se cierre para evitar corrupción o bloqueos.
  - Crea copias de seguridad automáticas (`ai_diffusion.backup`, `vision_tools.backup`) y restaura el estado anterior si ocurre algún error durante la extracción.
  - Valida las rutas de los paquetes ZIP antes de extraerlos (protección contra *Zip Slip*).
- 🧠 **Preservación de modelos locales**: Conserva automáticamente cualquier modelo `.gguf` adicional descargado en `vision_tools/models/` al actualizar el plugin.
- 🔄 **Actualizador de ComfyUI integrado**: Permite actualizar el repositorio principal de **ComfyUI** y todos sus `custom_nodes` instalados por Git (auto-detectando `~/FastDrive/ComfyUI-01` o `~/ComfyUI` en modo `--gui`, o especificando `--comfyui-dir`).
- 💻 **Detección automática de rutas (`pykrita`)**:
  - **Linux (XDG estándar)**: `~/.local/share/krita/pykrita`
  - **Linux (Flatpak)**: `~/.var/app/org.kde.krita/data/krita/pykrita`
  - **Windows**: `%APPDATA%\krita\pykrita`
  - **macOS**: `~/Library/Application Support/krita/pykrita`

---

## Instalación

1. Clona el repositorio:
   ```bash
   git clone https://github.com/davidbrum25/krita-ai_plugins_updater.git
   cd krita-ai_plugins_updater
   ```

2. Ejecuta el instalador (en Linux / KDE Plasma):
   ```bash
   ./install.sh
   ```

El instalador copiará el comando ejecutable en `~/.local/bin/update-krita-ai-tools` y creará el acceso directo en `~/.local/share/applications/update-krita-ai-tools.desktop`.

---

## Uso

### Desde el menú de aplicaciones (KDE Plasma)

Busca **"Update Krita AI Tools"** en KRunner (`Alt + Espacio`) o en el menú de aplicaciones (Kickoff). Se abrirá una ventana de Konsole comprobando y actualizando tanto los plugins de Krita como ComfyUI, mostrando notificaciones nativas al finalizar.

### Desde la terminal

```bash
update-krita-ai-tools
```
*(También puedes ejecutar directamente `./actualizar_plugins.sh`).*

### Opciones disponibles

```bash
# Solo comprobar si existen nuevas versiones sin descargar ni instalar
update-krita-ai-tools --check

# Actualizar plugins y además actualizar ComfyUI + todos sus custom_nodes
update-krita-ai-tools --comfyui-dir /ruta/a/ComfyUI

# Modo gráfico (usado por el launcher de KDE: notificaciones + pausa al finalizar)
update-krita-ai-tools --gui

# Aceptar e instalar automáticamente sin pedir confirmación
update-krita-ai-tools -y

# Forzar la descarga y reinstalación aunque ya estén en la última versión
update-krita-ai-tools --force

# Incluir versiones preliminares (Pre-release / Beta)
update-krita-ai-tools --include-pre

# Especificar una carpeta pykrita personalizada
update-krita-ai-tools --pykrita-dir /ruta/a/krita/pykrita
```

### Tabla de argumentos

| Argumento | Descripción |
| :--- | :--- |
| `--check` | Solo consulta las versiones disponibles en GitHub sin realizar cambios. |
| `--gui` | Activa notificaciones nativas de escritorio, auto-detecta ComfyUI y pausa al finalizar. |
| `-y`, `--yes` | Ejecución desatendida (confirma automáticamente la instalación). |
| `--force` | Fuerza la reinstalación de la última versión disponible. |
| `--include-pre` | Incluye versiones marcadas como *pre-release* en GitHub. |
| `--pykrita-dir <ruta>` | Define manualmente la ruta del directorio `pykrita`. |
| `--comfyui-dir <ruta>` | Ejecuta `git pull` en el directorio raíz de ComfyUI y en cada subcarpeta Git dentro de `custom_nodes/`. |
| `--no-comfyui` | Omite la actualización automática de ComfyUI cuando se usa `--gui`. |

---

## Licencia

MIT © [David Brum](https://github.com/davidbrum25)
