```bash
#!/bin/bash
set -e

# Si WORKSPACE no está definido, usar /workspace
if [ -z "$WORKSPACE" ]; then
    WORKSPACE="/workspace"
fi

FORGE="${WORKSPACE}/stable-diffusion-webui-forge"
DRIVE="gdrive:stable-drive"

echo "======================================"
echo "   PREPARANDO STABLE DIFFUSION FORGE"
echo "======================================"

# --------------------------------------
# 1. Crear carpetas
# --------------------------------------

mkdir -p "$FORGE/output"
mkdir -p "$FORGE/extensions"
mkdir -p "$FORGE/models"
mkdir -p "$FORGE/models/Stable-diffusion"
mkdir -p "$FORGE/models/Lora"

# --------------------------------------
# 2. Actualizar rclone
# --------------------------------------

echo "Actualizando rclone..."

curl https://rclone.org/install.sh | sudo bash

rclone version

# --------------------------------------
# 3. Recuperar datos desde Google Drive
# --------------------------------------

echo "Copiando extensions..."

rclone copy \
    "$DRIVE/extensions" \
    "$FORGE/extensions" \
    -P

echo "Copiando models..."

rclone copy \
    "$DRIVE/models" \
    "$FORGE/models" \
    -P

echo "Copiando configuraciones..."

for FILE in \
    config.json \
    ui-config.json \
    styles_integrated.csv
do
    rclone copyto \
        "$DRIVE/$FILE" \
        "$FORGE/$FILE" \
        -P
done

# --------------------------------------
# 4. Instalar requirements FaceSwapLab
# --------------------------------------

REQ="$FORGE/extensions/sd-webui-forge-faceswaplab/requirements.txt"

if [ -f "$REQ" ]; then
    echo "Instalando FaceSwapLab requirements..."

    /venv/main/bin/python -m pip install -r "$REQ"
fi

# --------------------------------------
# 5. Descargar PonyRealism
# --------------------------------------

MODEL="$FORGE/models/Stable-diffusion/ponyRealism_v22MainVAE.safetensors"

if [ ! -f "$MODEL" ]; then

    echo "Descargando PonyRealism..."

    wget -O "$MODEL" \
    "https://huggingface.co/TheImposterImposters/PonyRealism-v2.2MainVAE/resolve/main/ponyRealism_v22MainVAE.safetensors"

fi

# --------------------------------------
# 6. Descargar LoRA
# --------------------------------------

LORA="$FORGE/models/Lora/AmateurStyle_v1_PONY_REALISM.safetensors"

if [ ! -f "$LORA" ]; then

    echo "Descargando LoRA..."

    wget -O "$LORA" \
    "https://huggingface.co/KirtiKousik/New_loras/resolve/main/AmateurStyle_v1_PONY_REALISM.safetensors"

fi

# --------------------------------------
# 7. SINCRONIZAR OUTPUT
#    SOLO VAST -> GOOGLE DRIVE
# --------------------------------------

sync_output() {

    echo "======================================"
    echo "   GUARDANDO OUTPUT EN GOOGLE DRIVE"
    echo "======================================"

    rclone copy \
        "$FORGE/output" \
        "$DRIVE/output" \
        -P

}

# --------------------------------------
# 8. Sincronización automática cada 5 min
# --------------------------------------

(
    while true
    do
        sleep 300
        sync_output
    done
) &

SYNC_PID=$!

# --------------------------------------
# 9. Arrancar Forge
# --------------------------------------

cd "$FORGE"

echo "======================================"
echo "       ARRANCANDO FORGE"
echo "======================================"

./webui.sh

# --------------------------------------
# 10. Forge detenido
# --------------------------------------

echo "Forge detenido."

# Parar sincronización periódica
kill "$SYNC_PID" 2>/dev/null || true

# Última sincronización
echo "Última sincronización del output..."

sync_output

echo "======================================"
echo "              FIN"
echo "======================================"
```
