# Verificile

A tool to verify file extensions match their MIME types.

## Overview

Verificile ("verify files" / "the checks" in Romanian) is a Bash script that scans directories for files whose extensions don't match their actual content type as detected by the `file` command. It can identify mismatched extensions and help you fix them.

## Features

- Identifies files with incorrect extensions based on their actual MIME types
- Interactive mode for fixing anomalies as they're found
- Forensic mode for analyzing read-only filesystems
- Detailed reporting in TSV format for further analysis
- Color-coded output (with option to disable for basic terminals)
- Detection of new MIME types with suggestions for additions

## Requirements

- Bash shell
- `file` command (for MIME type detection)

## Installation

```bash
# Clone the repository
git clone https://github.com/thinko/verificile.git

# Make the script executable
cd verificile
chmod +x verificile.sh