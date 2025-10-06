#!/usr/bin/env bash

set -euo pipefail

# Конфигурация по умолчанию
recursive=false
dry_run=false
verbose=false
quiet=false
copy_files=false
backup=false
find_pairs=false
move_pairs=false
min_size=0
max_size=0
log_file="unpaired.log"
stats_file="file_stats.log"
backup_dir="backup"
pairs_dir="paired"

# Поддерживаемые форматы
raw_formats=("nef" "cr2" "arw" "dng")
jpg_extensions=("jpg" "JPG" "jpeg" "JPEG")

# Временные файлы
moved_file=""
temp_files=()

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции вывода
log_error() { echo -e "${RED}Error: $1${NC}" >&2; }
log_warning() { echo -e "${YELLOW}Warning: $1${NC}" >&2; }
log_info() { echo -e "${BLUE}Info: $1${NC}" >&2; }
log_success() { echo -e "${GREEN}$1${NC}"; }

# Функция cleanup
cleanup() {
    for temp_file in "${temp_files[@]}"; do
        if [ -f "$temp_file" ]; then
            rm -f "$temp_file"
        fi
    done
}

# Обработка сигналов
trap cleanup EXIT INT TERM

# Проверка зависимостей
check_dependencies() {
    local deps=("find" "mv" "cp" "mkdir" "date" "stat")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log_error "Required command '$dep' not found"
            exit 1
        fi
    done
}

# Показать справку
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Organize unpaired RAW photo files by moving them to separate directory.

Options:
    -r, --recursive      Search recursively in subdirectories
    -d, --dry-run        Simulate without actually moving files
    -c, --copy           Copy files instead of moving
    -b, --backup         Create backup before moving files
    --find-pairs         Find and show paired files
    --move-pairs         Move paired files to 'paired/' directory
    --min-size SIZE      Minimum file size (e.g., 1M, 100K)
    --max-size SIZE      Maximum file size (e.g., 50M, 1G)
    
    -v, --verbose        Verbose output
    -q, --quiet          Quiet mode (errors only)
    -l, --log FILE       Specify log file (default: unpaired.log)
    -h, --help           Show this help message

Examples:
    $0 -r -d                    # Dry run recursively
    $0 -l custom.log            # Use custom log file
    $0 --min-size 1M --max-size 50M  # Process files between 1MB and 50MB
    $0 --find-pairs             # Show paired files
    $0 --move-pairs -c          # Copy paired files instead of moving
EOF
}

# Парсинг размера файла
parse_size() {
    local size=$1
    if [[ $size =~ ^([0-9]+)([KMG]?)$ ]]; then
        local num=${BASH_REMATCH[1]}
        local unit=${BASH_REMATCH[2]}
        case $unit in
            K) echo $((num * 1024)) ;;
            M) echo $((num * 1024 * 1024)) ;;
            G) echo $((num * 1024 * 1024 * 1024)) ;;
            *) echo $num ;;
        esac
    else
        log_error "Invalid size format: $size"
        exit 1
    fi
}

# Проверка размера файла
check_file_size() {
    local file=$1
    local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
    
    if [ $min_size -gt 0 ] && [ $size -lt $min_size ]; then
        return 1
    fi
    if [ $max_size -gt 0 ] && [ $size -gt $max_size ]; then
        return 1
    fi
    return 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--recursive) recursive=true ;;
        -d|--dry-run) dry_run=true ;;
        -c|--copy) copy_files=true ;;
        -b|--backup) backup=true ;;
        --find-pairs) find_pairs=true ;;
        --move-pairs) move_pairs=true ;;
        -v|--verbose) verbose=true ;;
        -q|--quiet) quiet=true ;;
        -l|--log) log_file="$2"; shift ;;
        --min-size) min_size=$(parse_size "$2"); shift ;;
        --max-size) max_size=$(parse_size "$2"); shift ;;
        -h|--help) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Проверка конфликтующих опций
if [ "$verbose" = true ] && [ "$quiet" = true ]; then
    log_error "Cannot use both --verbose and --quiet"
    exit 1
fi

if [ "$find_pairs" = true ] && [ "$move_pairs" = true ]; then
    log_error "Cannot use both --find-pairs and --move-pairs"
    exit 1
fi

# Настройка вывода
if [ "$quiet" = true ]; then
    exec 3>/dev/null
    exec 4>/dev/null
elif [ "$verbose" = true ]; then
    exec 3>&1
    exec 4>&1
else
    exec 3>/dev/null
    exec 4>&1
fi

# Проверка зависимостей
check_dependencies

# Создание временного файла для подсчета
moved_file=$(mktemp)
temp_files+=("$moved_file")
echo 0 > "$moved_file"

# Функция для подсчёта файлов по типам
count_files() {
    local phase="$1"
    local find_cmd=("find" ".")
    
    if [ "$recursive" = false ]; then
        find_cmd+=("-maxdepth" "1")
    fi
    
    echo "=== File statistics $phase ===" > "$stats_file"
    
    # Подсчет RAW файлов
    for format in "${raw_formats[@]}"; do
        local raw_count=0
        while IFS= read -r -d '' file; do
            if check_file_size "$file"; then
                ((raw_count++))
            fi
        done < <("${find_cmd[@]}" -type f -name "*.$format" -print0 2>/dev/null || true)
        echo "${format^^} files: $raw_count" >> "$stats_file"
    done
    
    # Подсчет JPG файлов
    local jpg_count=0
    for ext in "${jpg_extensions[@]}"; do
        while IFS= read -r -d '' file; do
            if check_file_size "$file"; then
                ((jpg_count++))
            fi
        done < <("${find_cmd[@]}" -type f -name "*.$ext" -print0 2>/dev/null || true)
    done
    echo "JPG files: $jpg_count" >> "$stats_file"
    
    # Подсчет парных и непарных файлов
    local paired_count=0
    local unpaired_count=0
    
    for format in "${raw_formats[@]}"; do
        while IFS= read -r -d '' raw_file; do
            if ! check_file_size "$raw_file"; then
                continue
            fi
            
            local base_name="${raw_file%.*}"
            local has_pair=false
            
            for ext in "${jpg_extensions[@]}"; do
                if [ -f "$base_name.$ext" ] && check_file_size "$base_name.$ext"; then
                    has_pair=true
                    break
                fi
            done
            
            if [ "$has_pair" = true ]; then
                ((paired_count++))
            else
                ((unpaired_count++))
            fi
        done < <("${find_cmd[@]}" -type f -name "*.$format" -print0 2>/dev/null || true)
    done
    
    echo "Paired RAW+JPG: $paired_count" >> "$stats_file"
    echo "Unpaired RAW: $unpaired_count" >> "$stats_file"
    echo "=====================" >> "$stats_file"
}

# Функция для создания резервной копии
create_backup() {
    local file="$1"
    local backup_path="$backup_dir/$(dirname "$file")"
    
    mkdir -p "$backup_path"
    cp "$file" "$backup_dir/$file"
    log_info "Backup created: $backup_dir/$file" >&3
}

# Функция обработки файлов
process_file() {
    local operation="$1"  # "move" или "copy"
    local file="$2"
    local target_dir="$3"
    
    if [ "$dry_run" = true ]; then
        echo "[Dry Run] Would $operation: $file -> $target_dir/" >&3
        return 0
    fi
    
    # Создание резервной копии если нужно
    if [ "$backup" = true ] && [ "$operation" = "move" ]; then
        create_backup "$file"
    fi
    
    # Создание целевой директории
    mkdir -p "$target_dir"
    
    # Выполнение операции
    if [ "$operation" = "move" ]; then
        mv "$file" "$target_dir/"
    else
        cp "$file" "$target_dir/"
    fi
    
    # Логирование
    local action=$( [ "$operation" = "move" ] && echo "Moved" || echo "Copied" )
    echo "$(date +'%Y-%m-%d %H:%M:%S'): ${action} $file to $target_dir/" >> "$log_file"
    
    # Обновление счетчика
    local count=$(<"$moved_file")
    echo $((count + 1)) > "$moved_file"
    
    log_info "${action} $file to $target_dir/" >&3
}

# Функция поиска парных файлов
find_paired_files() {
    log_info "Searching for paired files..." >&4
    
    local find_cmd=("find" ".")
    if [ "$recursive" = false ]; then
        find_cmd+=("-maxdepth" "1")
    fi
    
    local paired_files=()
    
    for format in "${raw_formats[@]}"; do
        while IFS= read -r -d '' raw_file; do
            if ! check_file_size "$raw_file"; then
                continue
            fi
            
            local base_name="${raw_file%.*}"
            local has_pair=false
            
            for ext in "${jpg_extensions[@]}"; do
                if [ -f "$base_name.$ext" ] && check_file_size "$base_name.$ext"; then
                    has_pair=true
                    paired_files+=("$raw_file" "$base_name.$ext")
                    break
                fi
            done
        done < <("${find_cmd[@]}" -type f -name "*.$format" -print0 2>/dev/null || true)
    done
    
    if [ ${#paired_files[@]} -eq 0 ]; then
        log_info "No paired files found." >&4
        return
    fi
    
    log_info "Found $(( ${#paired_files[@]} / 2 )) paired files:" >&4
    for ((i=0; i<${#paired_files[@]}; i+=2)); do
        echo "  ${paired_files[i]} <-> ${paired_files[i+1]}" >&4
    done
}

# Основная логика обработки непарных файлов
process_unpaired_files() {
    log_info "Starting to process unpaired files..." >&4
    
    # Создание директорий и проверка прав
    mkdir -p unpaired
    if [ ! -w unpaired/ ]; then
        log_error "Cannot write to 'unpaired/'"
        exit 1
    fi
    
    if [ "$backup" = true ]; then
        mkdir -p "$backup_dir"
        if [ ! -w "$backup_dir" ]; then
            log_error "Cannot write to '$backup_dir'"
            exit 1
        fi
    fi
    
    # Поиск RAW файлов
    local find_cmd=("find" ".")
    if [ "$recursive" = false ]; then
        find_cmd+=("-maxdepth" "1")
    fi
    
    for format in "${raw_formats[@]}"; do
        log_info "Processing .$format files..." >&3
        
        while IFS= read -r -d '' raw_file; do
            if ! check_file_size "$raw_file"; then
                log_info "Skipping $raw_file (size filter)" >&3
                continue
            fi
            
            local base_name="${raw_file%.*}"
            local has_pair=false
            
            # Проверка наличия парного JPG
            for ext in "${jpg_extensions[@]}"; do
                if [ -f "$base_name.$ext" ] && check_file_size "$base_name.$ext"; then
                    has_pair=true
                    break
                fi
            done
            
            if [ "$has_pair" = false ]; then
                local operation=$( [ "$copy_files" = true ] && echo "copy" || echo "move" )
                process_file "$operation" "$raw_file" "unpaired"
            else
                log_info "Skipping paired file: $raw_file" >&3
            fi
        done < <("${find_cmd[@]}" -type f -name "*.$format" -print0 2>/dev/null || true)
    done
}

# Функция обработки парных файлов
process_paired_files_operation() {
    log_info "Processing paired files..." >&4
    
    mkdir -p "$pairs_dir"
    if [ ! -w "$pairs_dir" ]; then
        log_error "Cannot write to '$pairs_dir'"
        exit 1
    fi
    
    local find_cmd=("find" ".")
    if [ "$recursive" = false ]; then
        find_cmd+=("-maxdepth" "1")
    fi
    
    local operation=$( [ "$copy_files" = true ] && echo "copy" || echo "move" )
    
    for format in "${raw_formats[@]}"; do
        while IFS= read -r -d '' raw_file; do
            if ! check_file_size "$raw_file"; then
                continue
            fi
            
            local base_name="${raw_file%.*}"
            local jpg_file=""
            
            for ext in "${jpg_extensions[@]}"; do
                if [ -f "$base_name.$ext" ] && check_file_size "$base_name.$ext"; then
                    jpg_file="$base_name.$ext"
                    break
                fi
            done
            
            if [ -n "$jpg_file" ]; then
                # Создание поддиректории в pairs
                local relative_dir=$(dirname "$raw_file")
                local target_subdir="$pairs_dir"
                if [ "$relative_dir" != "." ] && [ "$recursive" = true ]; then
                    target_subdir="$pairs_dir/$relative_dir"
                fi
                
                process_file "$operation" "$raw_file" "$target_subdir"
                process_file "$operation" "$jpg_file" "$target_subdir"
            fi
        done < <("${find_cmd[@]}" -type f -name "*.$format" -print0 2>/dev/null || true)
    done
}

# Подтверждение действий
confirm_action() {
    if [ "$dry_run" = false ] && [ "$quiet" = false ]; then
        local action_type=""
        if [ "$find_pairs" = true ]; then
            return 0
        elif [ "$move_pairs" = true ]; then
            action_type="move/copy paired files"
        else
            action_type="move/copy unpaired files"
        fi
        
        read -p "This will $action_type. Continue? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
}

# Основная программа
main() {
    log_info "Starting photo organization script..." >&4
    
    # Собираем статистику до обработки
    count_files "before processing"
    if [ "$quiet" = false ]; then
        echo "=== Initial File Stats ===" >&4
        cat "$stats_file" >&4
        echo >&4
    fi
    
    # Выполнение выбранной операции
    if [ "$find_pairs" = true ]; then
        find_paired_files
    elif [ "$move_pairs" = true ]; then
        confirm_action
        process_paired_files_operation
    else
        confirm_action
        process_unpaired_files
    fi
    
    # Собираем статистику после обработки
    count_files "after processing"
    
    # Вывод результатов
    if [ "$dry_run" = false ] && [ "$find_pairs" = false ]; then
        local moved_count=$(<"$moved_file")
        if [ "$quiet" = false ]; then
            echo "=== Processing Results ===" >&4
            if [ "$move_pairs" = true ]; then
                echo "Processed $((moved_count / 2)) paired file sets" >&4
            else
                echo "Processed $moved_count unpaired file(s)" >&4
            fi
            echo "=== Final File Stats ===" >&4
            cat "$stats_file" >&4
        fi
        
        if [ $moved_count -gt 0 ]; then
            log_success "Operation completed successfully!" >&4
        else
            log_info "No files were processed." >&4
        fi
    fi
    
    log_info "Log file: $log_file" >&4
    log_info "Stats file: $stats_file" >&4
}

# Запуск основной программы
main
