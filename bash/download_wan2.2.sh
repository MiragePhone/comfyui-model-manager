#!/bin/bash

# ========================================
# Настройки
# ========================================
COMFYUI_DIR="$HOME/comfyui/ComfyUI" # Укажи в .env
CIVITAI_API_KEY=""  # Укажи в .env

# Пути
CHECKPOINTS_DIR="$COMFYUI_DIR/models/checkpoints"
DIFFUSION_DIR="$COMFYUI_DIR/models/diffusion_models"
CLIP_DIR="$COMFYUI_DIR/models/clip"
VAE_DIR="$COMFYUI_DIR/models/vae"
LORA_DIR="$COMFYUI_DIR/models/loras"
CONTROLNET_DIR="$COMFYUI_DIR/models/controlnet"
EMBEDDINGS_DIR="$COMFYUI_DIR/models/embeddings"
UPSCALERS_DIR="$COMFYUI_DIR/models/upscale_models"
TEXT_ENCODERS_DIR="$COMFYUI_DIR/models/text_encoders"


# Создаём все папки
mkdir -p "$CHECKPOINTS_DIR" "$CLIP_DIR" "$VAE_DIR" "$LORA_DIR" \
         "$CONTROLNET_DIR" "$EMBEDDINGS_DIR" "$UPSCALERS_DIR"

# Лог и README
ERROR_LOG="download_errors.log"
README_FILE="models_catalog.md"
> "$ERROR_LOG"
> "$README_FILE"

# ========================================
# Загрузка .env
# ========================================
if [ -f ".env" ]; then
    echo "📥 Загружаю .env"
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$CIVITAI_API_KEY" ]; then
    if [ -n "$CIVITAI_TOKEN" ]; then
        CIVITAI_API_KEY="$CIVITAI_TOKEN"
    else
        echo "⚠️  CIVITAI_API_KEY не задан. Ограниченный доступ к CivitAI."
        echo ""
    fi
fi

if [ -z "$COMFYUI_DIR" ]; then
    if [ -n "$COMFYUI_DIR" ]; then
        COMFYUI_DIR="$COMFYUI_DIR"
    else
        echo "⚠️  COMFYUI_DIR не задан. Используется $COMFYUI_DIR"
        echo ""
    fi
fi

# ========================================
# Списки моделей: (URL, DEST_DIR, FILENAME)
# ========================================
declare -a MODELS_LIST=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|$VAE_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors|$VAE_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_control_high_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_camera_high_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"   
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_control_low_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_camera_low_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_fun_inpaint_low_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|$DIFFUSION_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|$TEXT_ENCODERS_DIR|"
)

declare -a LORA_LIST=(
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors|$LORA_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_low_noise.safetensors|$LORA_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors|$LORA_DIR|"
    "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/loras/wan2.2_t2v_lightx2v_4steps_lora_v1.1_high_noise.safetensors|$LORA_DIR|"
)

declare -a CONTROLNET_LIST=(
)

declare -a EMBEDDINGS_LIST=(
)

declare -a UPSCALERS_LIST=(
)

# ========================================
# Временная база данных моделей
# Будет использоваться для README
# ========================================
declare -a MODEL_CATALOG=()

# Формат: type|name|trigger|description|url|local_path

# ========================================
# Утилиты
# ========================================
is_civitai_url() { [[ "$1" == *"civitai.com/api/download/models/"* ]]; }
extract_model_id() { echo "$1" | grep -oE 'models/[0-9]+' | cut -d'/' -f2; }

# Получение данных о модели через API
fetch_civitai_info() {
    local model_id=$1
    local api_url="https://civitai.com/api/v1/model-versions/by-id/$model_id"

    local headers=()
    [ -n "$CIVITAI_API_KEY" ] && headers+=(-H "Authorization: Bearer $CIVITAI_API_KEY")

    curl -s "${headers[@]}" "$api_url"
}

# Извлечение имени файла
get_filename_from_civitai() {
    local model_id=$1
    local response=$(fetch_civitai_info "$model_id")
    echo "$response" | grep -oE '"downloadUrl":"[^"]+"' | head -1 | sed 's/.*"downloadUrl":"\([^"]*\)".*/\1/' | xargs basename 2>/dev/null || return 1
}

# Извлечение триггер-слов
get_triggers_from_civitai() {
    local model_id=$1
    local response=$(fetch_civitai_info "$model_id")
    echo "$response" | grep -oE '"trainedWords":\[[^\]]*\]' | sed 's/.*"trainedWords":\[\(.*\)\].*/\1/' | tr -d '"' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' | paste -sd "," -
}

# Извлечение описания
get_description_from_civitai() {
    local model_id=$1
    local response=$(fetch_civitai_info "$model_id")
    echo "$response" | grep -oE '"description":"[^"]*"' | sed 's/.*"description":"\([^"]*\)".*/\1/' | sed 's/\\n/ /g' | cut -c -100 | sed 's/[^[:print:]]//g'
}

# ========================================
# Скачивание с логированием
# ========================================
download_file() {
    local url=$1
    local dest_dir=$2
    local filename_hint=$3
    local model_type=$4  # checkpoint, lora, controlnet и т.д.

    local filename="$filename_hint"
    local model_id=""
    local trigger_words=""
    local description=""

    # Определение имени
    if is_civitai_url "$url" && [ -z "$filename" ]; then
        model_id=$(extract_model_id "$url")
        if [ -n "$model_id" ]; then
            filename=$(get_filename_from_civitai "$model_id")
            if [ $? -ne 0 ] || [ -z "$filename" ]; then
                filename="model_${model_id}.safetensors"
            fi
        fi
    elif [ -z "$filename" ]; then
        filename=$(basename "$url" | sed -E 's/\?.*$//')
    fi

    local filepath="$dest_dir/$filename"

    # Пропуск, если уже есть
    if [ -f "$filepath" ]; then
        echo "[✔] Пропущено: $filename"
        return 0
    fi

    # Получение триггеров и описания (если CivitAI)
    if [ -n "$model_id" ] && [ "$model_type" == "lora" ] || [ "$model_type" == "embedding" ]; then
        trigger_words=$(get_triggers_from_civitai "$model_id")
        description=$(get_description_from_civitai "$model_id")
    fi

    # Заголовки
    local auth_header=""
    if is_civitai_url "$url" && [ -n "$CIVITAI_API_KEY" ]; then
        auth_header="Authorization: Bearer $CIVITAI_API_KEY"
    fi

    echo "[📥] Скачиваю: $filename"

    local download_cmd
    if command -v aria2c >/dev/null 2>&1; then
        if [ -n "$auth_header" ]; then
            download_cmd=(aria2c -x 16 -s 16 -k 1M --header="$auth_header" -o "$filepath" "$url")
        else
            download_cmd=(aria2c -x 16 -s 16 -k 1M -o "$filepath" "$url")
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ -n "$auth_header" ]; then
            download_cmd=(wget --header="$auth_header" -O "$filepath" "$url")
        else
            download_cmd=(wget -O "$filepath" "$url")
        fi
    else
        echo "❌ wget/aria2c не найден"
        echo "$url | wget/aria2c не найден" >> "$ERROR_LOG"
        return 1
    fi

    echo "[💡] Выполнем: ${download_cmd[@]}"
    if "${download_cmd[@]}"; then
        echo "[✅] Загружено: $filename"
        # Добавляем в каталог
        MODEL_CATALOG+=("$model_type|$filename|$trigger_words|$description|$url|$filepath")
        return 0
    else
        echo "❌ Ошибка: $url"
        echo "$url | Ошибка загрузки" >> "$ERROR_LOG"
        rm -f "$filepath" 2>/dev/null
        return 1
    fi
}

# ========================================
# Основной цикл
# ========================================
echo "=== Загрузка всех моделей для ComfyUI ==="
echo "Папка: $COMFYUI_DIR"
echo ""

SUCCESS_COUNT=0
FAILED_COUNT=0

# Загрузка всех типов
process_list() {
    local list_name="$1[@]"
    local model_type="$2"
    local dest_dir="$3"
    shift 3
    local urls=("$@")

    echo "🔹 Загрузка: $model_type..."
    for item in "${urls[@]}"; do
        IFS='|' read -r url dir filename <<< "$item"
        if download_file "$url" "$dir" "$filename" "$model_type"; then
            ((SUCCESS_COUNT++))
        else
            ((FAILED_COUNT++))
        fi
    done
}

process_list "MODELS_LIST" "checkpoint" "$CHECKPOINTS_DIR" "${MODELS_LIST[@]}"
process_list "LORA_LIST" "lora" "$LORA_DIR" "${LORA_LIST[@]}"
process_list "CONTROLNET_LIST" "controlnet" "$CONTROLNET_DIR" "${CONTROLNET_LIST[@]}"
process_list "EMBEDDINGS_LIST" "embedding" "$EMBEDDINGS_DIR" "${EMBEDDINGS_LIST[@]}"
process_list "UPSCALERS_LIST" "upscaler" "$UPSCALERS_DIR" "${UPSCALERS_LIST[@]}"

# ========================================
# Генерация README.md
# ========================================
{
    echo "# 🏗️ ComfyUI — Каталог загруженных моделей"
    echo ""
    echo "| Тип | Имя файла | Триггер-слова | Описание | Ссылка |"
    echo "|-----|-----------|----------------|----------|--------|"
    for entry in "${MODEL_CATALOG[@]}"; do
        IFS='|' read -r type name trigger desc url path <<< "$entry"
        url_md=$(echo "$url" | sed 's/|/\\|/g')
        name_md=$(echo "$name" | sed 's/|/\\|/g')
        trigger_md=$(echo "$trigger" | sed 's/|/\\|/g' | cut -c -80)
        desc_md=$(echo "$desc" | sed 's/|/\\|/g' | cut -c -60)
        echo "| $type | $name_md | $trigger_md | $desc_md | [Скачать]($url_md) |"
    done
} > "$README_FILE"

# ========================================
# Итог
# ========================================
echo ""
echo "========================================"
echo "✅ Загрузка завершена"
echo "   Успешно: $SUCCESS_COUNT"
echo "   Ошибок:  $FAILED_COUNT"
echo "   Каталог: $README_FILE"
echo "========================================"

if [ $FAILED_COUNT -gt 0 ]; then
    echo ""
    echo "📋 Ошибки:"
    cat "$ERROR_LOG"
fi

echo ""
echo "💡 Перезапустите ComfyUI, чтобы увидеть новые модели."
echo "   Проверьте: $README_FILE для описаний и триггеров."