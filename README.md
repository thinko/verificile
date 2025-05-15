# Verificile

A tool to verify file extensions match their MIME types.

## Overview

Verificile is a Bash script that scans directories for files whose extensions don't match their actual content type as detected by the `file` command. It can identify mismatched extensions and help you fix them.

## Features

- Identifies files with incorrect extensions based on their actual MIME types
- Interactive mode for fixing anomalies as they're found
- Forensic mode for reporting to console, but not writing any files
- Detailed reporting in TSV format for further analysis
- Color-coded output (with option to disable for basic terminals)
- Detection of new MIME types with suggestions for additions

## Requirements

- Bash shell

## Installation (system-wide)

```bash
git clone https://github.com/thinko/verificile.git
cd verificile
sudo cp verificile.sh /usr/local/bin/
chmod +x /usr/local/bin/verificile.sh
```

## Installation (user-local)

```bash
git clone https://github.com/thinko/verificile.git
cd verificile
mkdir -p ~/.local/bin
cp verificile.sh ~/.local/bin/
chmod +x ~/.local/bin/verificile.sh
```

## Usage

```bash
verificile.sh [OPTIONS] <directory> [<directory>...]
```

### Options

- `-h, --help`        - Display help information
- `-i, --interactive` - Interactive mode: fix anomalies as they're found
- `-n, --no-color`    - Disable colored output (for basic terminals)
- `-r, --recursive`   - Recursively check subdirectories
- `-f, --forensic`    - Forensic mode: don't write any files (implies -v)
- `-v, --verbose`     - Output anomalies to console when found (fixed-width format)
- `--debug`           - Enable debug mode to show detailed processing steps

### Examples

Basic usage:
```bash
./verificile.sh ~/Downloads
```

Interactive mode with recursive scanning:
```bash
./verificile.sh -i -r ~/Photos
```

Forensic mode for read-only analysis:
```bash
./verificile.sh -f /media/external-drive
```

## Output Files

Verificile generates timestamped output files to avoid overwriting previous results:

- `verificile_anomalies_YYYYMMDD_HHMMSS.tsv` - Tab-separated list of all anomalies found
- `verificile_renamed_YYYYMMDD_HHMMSS.log` - Log of all file rename operations

## Interactive Mode

In interactive mode, Verificile will stop at each anomaly and offer several options:

1. Fix extension (change to the correct extension)
2. Skip this file
3. Append extension (keep current name, add correct extension)
4. Custom rename (enter a new filename)

If the target filename already exists, you'll get additional options for handling the collision.

## Supported MIME Types

Verificile comes pre-configured to recognize many common file types including:

- Images: JPEG, PNG, GIF, BMP, WEBP, TIFF
- Documents: PDF, TXT, HTML
- Archives: ZIP, RAR, 7Z, TAR, GZ
- Media: MP4, WEBM, MKV, MP3, FLAC

The script will also suggest additions for any new MIME types it encounters.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
