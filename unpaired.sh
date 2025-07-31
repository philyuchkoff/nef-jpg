#!/bin/bash

set -euo pipefail

# Параметры
recursive=false
dry_run=false
log_file=""

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

# Создание директории unpaired внутри директории с фотками, если её нет, и проверка прав
mkdir -p unpaired
if [ ! -w unpaired/ ]; then
    echo "Error: Cannot write to 'unpaired/'" >&2
    exit 1
fi

# Ищем .nef файлы без соответствующих .jpg и переносим найденное в unpaired
find_cmd="find ."
$recursive || find_cmd+=" -maxdepth 1"
find_cmd+=" -type f -name \"*.nef\" -print0"

moved=0
eval "$find_cmd" | while IFS= read -r -d '' nef_file; do
    jpg_file="${nef_file%.*}.jpg"
    if [ ! -f "$jpg_file" ] && [ ! -f "${nef_file%.*}.JPG" ]; then
        if [ "$dry_run" = true ]; then
            echo "[Dry Run] Would move: $nef_file"
        else
            mv "$nef_file" unpaired/
            [ -n "$log_file" ] && echo "$(date): Moved $nef_file" >> "$log_file"
        fi
        ((moved++))
    fi
done

echo "Done. Moved $moved file(s) to 'unpaired/'"
