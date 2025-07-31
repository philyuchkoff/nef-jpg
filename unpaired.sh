#!/bin/bash

set -euo pipefail

# Параметры
recursive=false
dry_run=false
log_file="unpaired.log"
stats_file="file_stats.log"

# Обработка аргументов
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--recursive) recursive=true ;;
        -d|--dry-run) dry_run=true ;;
        -l|--log) log_file="$2"; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# Создание директории и проверка прав
mkdir -p unpaired
if [ ! -w unpaired/ ]; then
    echo "Error: Cannot write to 'unpaired/'" >&2
    exit 1
fi

# Функция для подсчёта файлов по типам
count_files() {
    echo "=== File statistics before processing ===" > "$stats_file"
    echo "NEF files: $(find . -maxdepth 1 -type f -name "*.nef" | wc -l)" >> "$stats_file"
    echo "JPG files: $(find . -maxdepth 1 -type f -name "*.jpg" -o -name "*.JPG" | wc -l)" >> "$stats_file"
    echo "Paired NEF+JPG: $(find . -maxdepth 1 -type f -name "*.nef" | while read -r f; do [ -f "${f%.*}.jpg" ] || [ -f "${f%.*}.JPG" ] && echo 1; done | wc -l)" >> "$stats_file"
    echo "Unpaired NEF: $(find . -maxdepth 1 -type f -name "*.nef" | while read -r f; do [ -f "${f%.*}.jpg" ] || [ -f "${f%.*}.JPG" ] || echo 1; done | wc -l)" >> "$stats_file"
    echo "=====================" >> "$stats_file"
}

# Собираем статистику до обработки
count_files
cat "$stats_file"

# Поиск .nef файлов
find_cmd="find ."
$recursive || find_cmd+=" -maxdepth 1"
find_cmd+=" -type f -name \"*.nef\" -print0"

# Используем временный файл для подсчёта перемещённых файлов
moved_file=$(mktemp)
echo 0 > "$moved_file"

eval "$find_cmd" | while IFS= read -r -d '' nef_file; do
    jpg_file="${nef_file%.*}.jpg"
    if [ ! -f "$jpg_file" ] && [ ! -f "${nef_file%.*}.JPG" ]; then
        if [ "$dry_run" = true ]; then
            echo "[Dry Run] Would move: $nef_file"
        else
            mv "$nef_file" unpaired/
            echo "$(date +'%Y-%m-%d %H:%M:%S'): Moved $nef_file" >> "$log_file"
        fi
        count=$(<"$moved_file")
        echo $((count + 1)) > "$moved_file"
    fi
done

moved=$(<"$moved_file")
rm "$moved_file"

# Собираем статистику после обработки
count_files

echo "=== Processing Results ==="
echo "Moved $moved file(s) to 'unpaired/'"
echo "=== Current File Stats ==="
cat "$stats_file"
