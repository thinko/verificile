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
