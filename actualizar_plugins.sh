#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Actualización Automática de Plugins de Krita:
  1. Krita AI Diffusion (https://github.com/Acly/krita-ai-diffusion)
  2. Krita Vision Tools (https://github.com/Acly/krita-vision-tools)

Compatible con Linux y Windows. No requiere librerías externas (solo Python estándar).
"""

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

# --- Configuración de los repositorios ---
REPOS = {
    "ai_diffusion": {
        "name": "Krita AI Diffusion",
        "repo": "Acly/krita-ai-diffusion",
        "folder": "ai_diffusion",
        "desktop": "ai_diffusion.desktop",
        "asset_filter": lambda name, os_name: "krita_ai_diffusion" in name.lower() and name.endswith(".zip"),
    },
    "vision_tools": {
        "name": "Krita Vision Tools",
        "repo": "Acly/krita-vision-tools",
        "folder": "vision_tools",
        "desktop": "vision_tools.desktop",
        "asset_filter": lambda name, os_name: os_name in name.lower() and name.endswith(".zip"),
    },
}

MANIFEST_FILENAME = ".plugins_installed_manifest.json"


def print_banner():
    banner = r"""
============================================================
      ACTUALIZADOR DE PLUGINS DE KRITA (AI & VISION)
============================================================
"""
    print(banner)


def detect_os():
    """Detecta el sistema operativo simplificado ('windows', 'linux', 'darwin')."""
    sys_name = platform.system().lower()
    if "windows" in sys_name:
        return "windows"
    elif "linux" in sys_name:
        return "linux"
    elif "darwin" in sys_name:
        return "darwin"
    return sys_name


def get_default_pykrita_path():
    """Obtiene la ruta estándar de la carpeta pykrita de Krita según el SO."""
    os_name = detect_os()
    if os_name == "windows":
        appdata = os.environ.get("APPDATA")
        if appdata:
            return Path(appdata) / "krita" / "pykrita"
        return Path.home() / "AppData" / "Roaming" / "krita" / "pykrita"
    elif os_name == "linux":
        # Comprobar Flatpak o ruta estándar XDG
        flatpak_path = Path.home() / ".var" / "app" / "org.kde.krita" / "data" / "krita" / "pykrita"
        if flatpak_path.exists():
            return flatpak_path
        return Path.home() / ".local" / "share" / "krita" / "pykrita"
    elif os_name == "darwin":
        return Path.home() / "Library" / "Application Support" / "krita" / "pykrita"
    else:
        return Path.home() / ".local" / "share" / "krita" / "pykrita"


def is_krita_running():
    """Comprueba si el proceso de Krita está activo para evitar archivos bloqueados."""
    os_name = detect_os()
    try:
        if os_name == "windows":
            res = subprocess.run(
                ["tasklist", "/FI", "IMAGENAME eq krita.exe", "/NH"],
                capture_output=True,
                text=True,
                check=False,
            )
            return "krita.exe" in res.stdout.lower()
        else:
            res = subprocess.run(["pgrep", "-x", "krita"], capture_output=True, text=True, check=False)
            return res.returncode == 0
    except Exception:
        return False


def wait_for_krita_closure():
    """Advierte al usuario si Krita está abierto y espera a que lo cierre."""
    if is_krita_running():
        print("\n[!] AVISO: Krita se encuentra actualmente en ejecución.")
        print("    Para actualizar los plugins de forma segura, cierra Krita primero.")
        while is_krita_running():
            input("    Por favor, cierra Krita y presiona [ENTER] para continuar...")
        print("[+] Krita se ha cerrado correctamente. Continuando...\n")


def load_manifest(pykrita_dir: Path):
    """Carga el registro de versiones instaladas."""
    manifest_path = pykrita_dir / MANIFEST_FILENAME
    if manifest_path.exists():
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}


def save_manifest(pykrita_dir: Path, manifest: dict):
    """Guarda el registro de versiones instaladas."""
    manifest_path = pykrita_dir / MANIFEST_FILENAME
    try:
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
    except Exception as e:
        print(f"[-] No se pudo guardar el manifest: {e}")


def get_current_installed_version(pykrita_dir: Path, plugin_id: str, manifest: dict):
    """Obtiene la versión instalada actualmente (desde manifest o inspección local)."""
    if plugin_id in manifest and "version" in manifest[plugin_id]:
        return manifest[plugin_id]["version"]

    if plugin_id == "ai_diffusion":
        init_file = pykrita_dir / "ai_diffusion" / "__init__.py"
        if init_file.exists():
            try:
                content = init_file.read_text(encoding="utf-8", errors="ignore")
                match = re.search(r'__version__\s*=\s*["\']([^"\']+)["\']', content)
                if match:
                    ver = match.group(1)
                    return f"v{ver}" if not ver.startswith("v") else ver
            except Exception:
                pass
        if (pykrita_dir / "ai_diffusion").exists():
            return "instalado (versión previa)"

    if plugin_id == "vision_tools":
        if (pykrita_dir / "vision_tools").exists():
            return "instalado (versión previa)"

    return None


def fetch_release_info(repo: str, os_name: str, asset_filter, include_pre: bool = False):
    """Consulta la API de GitHub para encontrar el release compatible más reciente."""
    url = f"https://api.github.com/repos/{repo}/releases"
    headers = {"User-Agent": "Krita-Plugin-AutoUpdater"}
    req = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            releases = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"[-] Error al consultar GitHub para {repo}: {e}")
        return None

    def search_in_releases(allow_pre):
        for release in releases:
            if not allow_pre and release.get("prerelease", False):
                continue
            tag_name = release.get("tag_name")
            for asset in release.get("assets", []):
                asset_name = asset.get("name", "")
                download_url = asset.get("browser_download_url", "")
                size = asset.get("size", 0)

                if asset_filter(asset_name, os_name):
                    return {
                        "tag_name": tag_name,
                        "release_name": release.get("name", tag_name),
                        "asset_name": asset_name,
                        "download_url": download_url,
                        "size": size,
                        "prerelease": release.get("prerelease", False),
                        "published_at": release.get("published_at"),
                    }
        return None

    result = search_in_releases(allow_pre=include_pre)
    if not result and not include_pre:
        result = search_in_releases(allow_pre=True)

    return result


def download_file_with_progress(url: str, dest_path: Path):
    """Descarga un archivo mostrando barra de progreso en consola."""
    req = urllib.request.Request(url, headers={"User-Agent": "Krita-Plugin-AutoUpdater"})
    with urllib.request.urlopen(req, timeout=60) as resp, open(dest_path, "wb") as out_file:
        total_size = int(resp.headers.get("content-length", 0))
        downloaded = 0
        chunk_size = 128 * 1024
        start_time = time.time()

        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            out_file.write(chunk)
            downloaded += len(chunk)

            if total_size > 0:
                percent = (downloaded / total_size) * 100
                mb_down = downloaded / (1024 * 1024)
                mb_tot = total_size / (1024 * 1024)
                elapsed = time.time() - start_time
                speed = (mb_down / elapsed) if elapsed > 0 else 0
                bar_len = 30
                filled = int(bar_len * downloaded / total_size)
                bar = "=" * filled + ">" + " " * (bar_len - filled - 1) if filled < bar_len else "=" * bar_len
                sys.stdout.write(f"\r    [{bar}] {percent:5.1f}% | {mb_down:5.1f}/{mb_tot:5.1f} MB ({speed:4.1f} MB/s)")
                sys.stdout.flush()

        sys.stdout.write("\n")


def backup_existing(pykrita_dir: Path, folder_name: str, desktop_name: str):
    """Crea una copia de seguridad del plugin actual."""
    plugin_dir = pykrita_dir / folder_name
    desktop_file = pykrita_dir / desktop_name
    backup_dir = pykrita_dir / f"{folder_name}.backup"

    if backup_dir.exists():
        shutil.rmtree(backup_dir, ignore_errors=True)

    if plugin_dir.exists():
        shutil.copytree(plugin_dir, backup_dir)
        if desktop_file.exists():
            shutil.copy2(desktop_file, backup_dir / desktop_name)
        return backup_dir
    return None


def preserve_custom_models(vision_tools_dir: Path, temp_cache: Path):
    """Preserva cualquier modelo .gguf extra en vision_tools/models/."""
    models_dir = vision_tools_dir / "models"
    if not models_dir.exists():
        return []

    saved_models = []
    for model_path in models_dir.rglob("*.gguf"):
        rel_path = model_path.relative_to(models_dir)
        dest = temp_cache / rel_path
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(model_path, dest)
        saved_models.append(rel_path)

    return saved_models


def restore_custom_models(vision_tools_dir: Path, temp_cache: Path, saved_models: list):
    """Restaura los modelos preservados en la nueva carpeta models/."""
    models_dir = vision_tools_dir / "models"
    for rel_path in saved_models:
        src = temp_cache / rel_path
        dest = models_dir / rel_path
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)


def install_plugin(pykrita_dir: Path, plugin_id: str, zip_path: Path):
    """Extrae el archivo zip del plugin en pykrita de forma segura."""
    cfg = REPOS[plugin_id]
    folder_name = cfg["folder"]
    desktop_name = cfg["desktop"]

    target_folder = pykrita_dir / folder_name
    temp_models_cache = None
    saved_models = []

    if plugin_id == "vision_tools" and target_folder.exists():
        temp_models_cache = Path(tempfile.mkdtemp(prefix="krita_models_backup_"))
        saved_models = preserve_custom_models(target_folder, temp_models_cache)
        if saved_models:
            print(f"    [i] Modelos preservados ({len(saved_models)} archivos):")
            for m in saved_models:
                print(f"        - {m}")

    backup_path = backup_existing(pykrita_dir, folder_name, desktop_name)
    if backup_path:
        print(f"    [i] Copia de seguridad guardada en: {backup_path.name}")

    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(pykrita_dir)

        if temp_models_cache and saved_models:
            restore_custom_models(target_folder, temp_models_cache, saved_models)
            shutil.rmtree(temp_models_cache, ignore_errors=True)

        return True
    except Exception as e:
        print(f"[-] ERROR durante la extracción: {e}")
        if backup_path and backup_path.exists():
            print("    [!] Restaurando copia de seguridad...")
            if target_folder.exists():
                shutil.rmtree(target_folder, ignore_errors=True)
            shutil.copytree(backup_path, target_folder)
            backup_desktop = backup_path / desktop_name
            if backup_desktop.exists():
                shutil.copy2(backup_desktop, pykrita_dir / desktop_name)
        return False


def update_comfyui_git_repos(comfy_root: Path):
    """Actualiza ComfyUI y sus custom nodes mediante git pull."""
    if not comfy_root.exists():
        print(f"[-] La ruta de ComfyUI no existe: {comfy_root}")
        return

    print("\n------------------------------------------------------------")
    print(f"[*] Comprobando actualizaciones para ComfyUI en:\n    {comfy_root}")
    print("------------------------------------------------------------")

    def run_git_pull(repo_dir: Path, label: str):
        if (repo_dir / ".git").exists():
            print(f"  -> Actualizando {label}...")
            try:
                res = subprocess.run(
                    ["git", "pull"],
                    cwd=repo_dir,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                first_line = res.stdout.strip().split("\n")[0] if res.stdout else "Completado"
                print(f"     Resultado: {first_line}")
            except Exception as e:
                print(f"     Error al ejecutar git pull: {e}")
        else:
            print(f"  [!] {label} no es un repositorio git (se omite git pull).")

    run_git_pull(comfy_root, "ComfyUI (Core)")

    custom_nodes_dir = comfy_root / "custom_nodes"
    if custom_nodes_dir.exists():
        for item in sorted(custom_nodes_dir.iterdir()):
            if item.is_dir() and (item / ".git").exists():
                run_git_pull(item, f"Nodo: {item.name}")


def main():
    parser = argparse.ArgumentParser(
        description="Actualizador automático para Krita AI Diffusion y Krita Vision Tools."
    )
    parser.add_argument(
        "--pykrita-dir",
        type=str,
        default=None,
        help="Ruta personalizada a la carpeta pykrita de Krita.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Solo comprueba si hay nuevas versiones sin descargar ni instalar.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Fuerza la descarga e instalación aunque ya esté en la versión más reciente.",
    )
    parser.add_argument(
        "--include-pre",
        action="store_true",
        help="Permite actualizar a versiones pre-release (beta/preview).",
    )
    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Acepta automáticamente la instalación sin pedir confirmación interactiva.",
    )
    parser.add_argument(
        "--comfyui-dir",
        type=str,
        default=None,
        help="Ruta opcional a la carpeta de ComfyUI para actualizar su core y nodos mediante git.",
    )
    args = parser.parse_args()

    print_banner()

    os_name = detect_os()
    print(f"[*] Sistema operativo detectado: {os_name.capitalize()} ({platform.machine()})")

    if args.pykrita_dir:
        pykrita_dir = Path(args.pykrita_dir).resolve()
    else:
        pykrita_dir = get_default_pykrita_path().resolve()

    print(f"[*] Carpeta pykrita objetivo:\n    {pykrita_dir}")

    if not pykrita_dir.exists():
        if args.check:
            print(f"[i] La carpeta pykrita aún no existe en este sistema.")
        else:
            print(f"[i] Creando carpeta pykrita: {pykrita_dir}")
            pykrita_dir.mkdir(parents=True, exist_ok=True)

    manifest = load_manifest(pykrita_dir)

    print("\n" + "=" * 60)
    print("  CONSULTANDO VERSIONES DISPONIBLES EN GITHUB...")
    print("=" * 60)

    updates_to_apply = []

    for plugin_id, cfg in REPOS.items():
        print(f"\n[+] Plugin: {cfg['name']} ({cfg['repo']})")

        installed_ver = get_current_installed_version(pykrita_dir, plugin_id, manifest)
        print(f"    - Versión instalada actualmente: {installed_ver or 'No instalado'}")

        print("    - Consultando último release...")
        latest_info = fetch_release_info(cfg["repo"], os_name, cfg["asset_filter"], include_pre=args.include_pre)

        if not latest_info:
            print(f"    [-] No se encontró un paquete compatible para tu sistema ({os_name}).")
            continue

        latest_tag = latest_info["tag_name"]
        pre_tag = " [Pre-release]" if latest_info.get("prerelease") else ""
        print(f"    - Última versión disponible:   {latest_tag}{pre_tag}")
        print(f"    - Paquete a descargar:         {latest_info['asset_name']} ({latest_info['size'] / (1024*1024):.1f} MB)")

        needs_update = False
        if args.force:
            needs_update = True
            print("    [!] Modo --force activo: se actualizará/reinstalará.")
        elif not installed_ver:
            needs_update = True
            print("    [!] El plugin no está instalado. Se procederá a instalarlo.")
        elif installed_ver != latest_tag:
            needs_update = True
            print(f"    [★] ¡NUEVA VERSIÓN DISPONIBLE! ({installed_ver} -> {latest_tag})")
        else:
            print("    [✓] Ya tienes la versión más reciente.")

        if needs_update:
            updates_to_apply.append((plugin_id, cfg, latest_info))

    if args.check:
        print("\n[*] Modo solo comprobación (--check) finalizado.")
        return

    if not updates_to_apply:
        print("\n[✓] ¡Todos los plugins están al día! No se requieren actualizaciones.")
    else:
        print("\n" + "=" * 60)
        print(f"  ACTUALIZACIONES PENDIENTES: {len(updates_to_apply)}")
        print("=" * 60)
        for _, cfg, info in updates_to_apply:
            print(f"  • {cfg['name']}: {info['tag_name']} ({info['asset_name']})")

        if not args.yes and sys.stdin.isatty():
            confirm = input("\n¿Deseas descargar e instalar estas actualizaciones ahora? [S/n]: ").strip().lower()
            if confirm not in ["", "s", "si", "y", "yes"]:
                print("[-] Actualización cancelada por el usuario.")
                return

        wait_for_krita_closure()

        with tempfile.TemporaryDirectory(prefix="krita_plugin_update_") as temp_dir:
            temp_path = Path(temp_dir)

            for plugin_id, cfg, info in updates_to_apply:
                print(f"\n[*] Procesando {cfg['name']}...")
                zip_filename = temp_path / info["asset_name"]

                print(f"    Descargando {info['asset_name']}...")
                try:
                    download_file_with_progress(info["download_url"], zip_filename)
                except Exception as e:
                    print(f"    [-] Error durante la descarga: {e}")
                    continue

                print(f"    Instalando en pykrita...")
                success = install_plugin(pykrita_dir, plugin_id, zip_filename)

                if success:
                    manifest[plugin_id] = {
                        "version": info["tag_name"],
                        "asset": info["asset_name"],
                        "updated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                    }
                    save_manifest(pykrita_dir, manifest)
                    print(f"    [✓] {cfg['name']} instalado/actualizado con éxito a {info['tag_name']}.")
                else:
                    print(f"    [-] Hubo un problema al instalar {cfg['name']}.")

        print("\n[✓] ¡Proceso de actualización de plugins finalizado!")
        print("    Recuerda reiniciar o abrir Krita para cargar los nuevos cambios.")

    if args.comfyui_dir:
        update_comfyui_git_repos(Path(args.comfyui_dir).resolve())

    print("\n============================================================")
    print("                    LISTO PARA USAR                         ")
    print("============================================================\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n[-] Proceso interrumpido por el usuario.")
        sys.exit(1)
    except Exception as e:
        print(f"\n[-] Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
