#!/bin/bash

# Создаем директорию unpaired внутри директории с фотками, если её нет
mkdir -p unpaired

# Ищем .nef файлы без соответствующих .jpg и переносим найденное в unpaired
find . -maxdepth 1 -type f -name "*.nef" | while read -r nef_file; do
    jpg_file="${nef_file%.*}.jpg"
    if [ ! -f "$jpg_file" ]; then
        mv "$nef_file" unpaired/
        echo "Moved unpaired file: $nef_file"
    fi
done
