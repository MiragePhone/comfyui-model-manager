#!/bin/bash

# Настройки
CIVITAI_API_KEY="13230cf59b4e8b027994644873087942"  # ← Замени на свой API-ключ (можно оставить пустым, если не нужен)
BASE_URL="https://civitai.com/api/v1/models"
BASE_URL="https://civitai.com/api/v1/models"

# Проверка аргумента
if [ -z "$1" ]; then
  echo "Использование: $0 <model_version_id>"
  exit 1
fi

MODEL_VERSION_ID="$1"

echo "Получаем информацию о версии модели $MODEL_VERSION_ID..."

# Формируем заголовки (с API-ключом, если указан)
if [ -n "$CIVITAI_API_KEY" ]; then
  AUTH_HEADER="Authorization: Bearer $CIVITAI_API_KEY"
else
  echo "API-ключ не указан или оставлен по умолчанию — запрос без авторизации."
  AUTH_HEADER=""
fi

# Получаем данные о версии модели
if [ -n "$AUTH_HEADER" ]; then
  echo "Выполняю curl -X GET  $BASE_URL/$MODEL_VERSION_ID?token=$CIVITAI_API_KEY"
  RESPONSE=$(curl -X GET -H "Content-Type: application/json" "$BASE_URL/$MODEL_VERSION_ID?token=$CIVITAI_API_KEY")
  echo "Ответ: $RESPONSE"
else
  RESPONSE=$(curl -s "$BASE_URL/$MODEL_VERSION_ID")
fi

# Проверка, есть ли ошибка
if echo "$RESPONSE" | grep -q "error"; then
  echo "Ошибка от API: $(echo "$RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)"
  exit 1
fi

# Извлекаем downloadUrl (ищем первую ссылку на файл)
DOWNLOAD_URL=$(echo "$RESPONSE" | grep -o '"downloadUrl":"[^"]*"' | head -1 | cut -d':' -f2- | tr -d '"')

# Извлекаем имя файла
FILENAME=$(echo "$RESPONSE" | grep -o '"name":"[^"]*"' | head -1 | cut -d':' -f2- | tr -d '"')".safetensors"

# Проверка, нашли ли данные
if [ -z "$DOWNLOAD_URL" ] || [ -z "$FILENAME" ]; then
  echo "Не удалось извлечь ссылку или имя файла. Ответ API:"
  #echo "$RESPONSE" | head -20
  exit 1
fi

echo "Название файла: $FILENAME"
echo "Ссылка на скачивание: $DOWNLOAD_URL"
echo "Скачиваем..."

# Добавляем заголовок авторизации к wget, если есть ключ
if [ -n "$CIVITAI_API_KEY" ]; then
  wget  -O "$FILENAME" "$DOWNLOAD_URL?token=$CIVITAI_API_KEY"
else
  wget -O "$FILENAME" "$DOWNLOAD_URL"
fi

# Проверка успешности загрузки
if [ $? -eq 0 ]; then
  echo "✅ Успешно скачано: $FILENAME"
else
  echo "❌ Ошибка при скачивании."
  exit 1
fi