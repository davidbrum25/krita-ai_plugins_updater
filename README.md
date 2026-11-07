# Krita AI Plugins & ComfyUI Updater

Un script ligero y multiplataforma (Linux, Windows y macOS) para comprobar, descargar y mantener actualizados automáticamente los plugins de Inteligencia Artificial para **Krita**, junto con la opción de actualizar el backend de **ComfyUI** y sus nodos personalizados (`custom_nodes`).

Escrito en Python 3 utilizando únicamente la librería estándar (sin dependencias externas).

---

## Plugins soportados

1. **[Krita AI Diffusion](https://github.com/Acly/krita-ai-diffusion)** (`Acly/krita-ai-diffusion`)
   Generación de imágenes, inpainting, outpainting, escalado y control en tiempo real dentro de Krita.
2. **[Krita Vision Tools](https://github.com/Acly/krita-vision-tools)** (`Acly/krita-vision-tools`)
    Segmentación inteligente de objetos, eliminación de fondos y herramientas de selección asistida por IA.

---

## Características

- 🔍 **Comprobación inteligente de versiones**: Consulta la API oficial de GitHub Releases y compara con la versión instalada localmente (mediante archivo manifest `.plugins_installed_manifest.json` o inspección de `__init__.py`).
- 📦 **Sin dependencias externas**: Funciona con cualquier instalación estándar de Python 3 (`urllib`, `zipfile`, `pathlib`, etc.).
- 🛡️ **Actualización segura con respaldo**:
  - Detecta si **Krita** está en ejecución antes de modificar archivos y espera a que se cierre para evitar corrupción o bloqueos.
  - Crea copias de seguridad automáticas (`ai_diffusion.backup`, `vision_tools.backup`) y restaura el estado anterior si ocurre algún error durante la extracción.
  - Valida las rutas de los paquetes ZIP antes de extraerlos (protección contra *Zip Slip*).
- 🧠 **Preservación de modelos locales**: Conserva automáticamente cualquier modelo `.gguf` adicional descargado en `vision_tools/models/` al actualizar el plugin.
- 🔄 **Actualizador de ComfyUI integrado**: Permite actualizar el repositorio principal de **ComfyUI** y todos sus `custom_nodes` instalados por Git mediante `--comfyui-dir`.
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

2. Asegúrate de que el script tenga permisos de ejecución (en Linux/macOS):
   ```bash
   chmod +x actualizar_plugins.sh
   ```

---

## Uso

### Ejecución estándar (interactiva)

```bash
./actualizar_plugins.sh
```
*(En Windows o cualquier sistema también puedes ejecutarlo con `python3 actualizar_plugins.sh` o `python actualizar_plugins.sh`).*

### Opciones disponibles

```bash
# Solo comprobar si existen nuevas versiones sin descargar ni instalar
./actualizar_plugins.sh --check

# Actualizar plugins y además actualizar ComfyUI + todos sus custom_nodes
./actualizar_plugins.sh --comfyui-dir /ruta/a/ComfyUI

# Aceptar e instalar automáticamente sin pedir confirmación
./actualizar_plugins.sh -y

# Forzar la descarga y reinstalación aunque ya estén en la última versión
./actualizar_plugins.sh --force

# Incluir versiones preliminares (Pre-release / Beta)
./actualizar_plugins.sh --include-pre

# Especificar una carpeta pykrita personalizada
./actualizar_plugins.sh --pykrita-dir /ruta/a/krita/pykrita
```

### Tabla de argumentos

| Argumento | Descripción |
| :--- | :--- |
| `--check` | Solo consulta las versiones disponibles en GitHub sin realizar cambios. |
| `-y`, `--yes` | Ejecución desatendida (confirma automáticamente la instalación). |
| `--force` | Fuerza la reinstalación de la última versión disponible. |
| `--include-pre` | Incluye versiones marcadas como *pre-release* en GitHub. |
| `--pykrita-dir <ruta>` | Define manualmente la ruta del directorio `pykrita`. |
| `--comfyui-dir <ruta>` | Ejecuta `git pull` en el directorio raíz de ComfyUI y en cada subcarpeta Git dentro de `custom_nodes/`. |

---

## Licencia

MIT © [David Brum](https://github.com/davidbrum25)
