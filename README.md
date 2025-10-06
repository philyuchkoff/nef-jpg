# NEF-JPG Pair Manager

[На русском](README-ru.md)

### _Photo Organizer Script - a bash script for automated management of RAW photo files_

A robust bash script for organizing photo files by moving/copying unpaired RAW files to a separate directory. Perfect for photographers who want to clean up their photo collections.

### **Key Features**

- Multi-format Support: Handles NEF, CR2, ARW, DNG RAW formats and JPG/JPEG counterparts
- Flexible Operations: Move or copy files, dry-run simulation, backup options
- Smart Filtering: Filter by file size, recursive directory search
- Dual Modes: Find unpaired RAW files OR find and process paired files
- Comprehensive Logging: Detailed logs and statistics with verbose/quiet modes
- Safety First: Backup options, confirmation prompts, and strict error handling
        
### **Installation**

```
git clone https://github.com/philyuchkoff/nef-jpg.git
cd nef-jpg
chmod +x unpaired.sh
```

### **Usage**

#### Basic Examples
```
# Find and move unpaired RAW files (non-recursive)
./unpaired.sh

# Dry run to see what would be moved
./unpaired.sh -dr

# Recursive search with verbose output
./unpaired.sh -rv

# Copy instead of move, with backup
./unpaired.sh -cb
```

#### Advanced Examples
```
# Process only large files (1MB to 50MB)
./unpaired.sh --min-size 1M --max-size 50M

# Find and display paired files without moving
./unpaired.sh --find-pairs -v

# Move paired files to separate directory
./unpaired.sh --move-pairs

# Custom log file with quiet operation
./unpaired.sh -q -l my_photos.log
```
----------

### **Command Line Options**

`-r`, `--recursive`	Search subdirectories recursively

`-d`, `--dry-run`	Simulate without moving files

`-c`, `--copy`	Copy files instead of moving

`-b`, `--backup`	Create backup before moving

`--find-pairs`	Find and show paired files

`--move-pairs`	Move paired files to 'paired/' directory

`--min-size SIZE`	Minimum file size (e.g., 1M, 100K)

`--max-size SIZE`	Maximum file size (e.g., 50M, 1G)

`-v`, `--verbose`	Verbose output

`-q`, `--quiet`	Quiet mode (errors only)

`-l`, `--log FILE`	Custom log file (default: unpaired.log)

`-h`, `--help`	Show help message

### **Supported Formats**
- RAW Formats: NEF, CR2, ARW, DNG
- JPEG Formats: JPG, JPEG (case insensitive)

### **Output Files**
- `unpaired.log` - Operation log with timestamps

- `file_stats.log` - Before/after file statistics

- `unpaired/` - Directory for unpaired RAW files

- `paired/` - Directory for paired files (when using `--move-pairs`)

- `backup/` - Backup directory (when using `--backup`)

### **Safety Features**
- Dry-run mode: Test operations without affecting files
- Backup option: Create backups before moving files
- Confirmation prompts: Confirm destructive operations
- Size filtering: Process only files within specified size range
- Error handling: Strict error checking with set -euo pipefail

### **Requirements**
- Bash 4.0 or newer
- Standard Unix utilities: find, mv, cp, mkdir, stat

### **License**
MIT License
