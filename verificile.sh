#!/bin/bash

# -----------------------------------------------------------------------------
# Verificile - A tool to verify file extensions match their MIME types
# -----------------------------------------------------------------------------
# Created by: thinko
# Version: 1.0.0
# Date: 2025-05-15
# -----------------------------------------------------------------------------
# Usage: ./verificile.sh [OPTIONS] <directory> [<directory>...]
#   <directory>: One or more directories to check.
#
#   The script compares each file's detected MIME type (via the `file` command)
#   with its extension to see if they match known valid extensions.
#
# OPTIONS:
#   -i, --interactive  Interactive mode: fix anomalies as they're found.
#   -r, --recursive    Recursively check subdirectories.
#   -v, --verbose      Output anomalies to console when found (fixed-width format).
#   --debug            Enable debug mode to show detailed processing steps.
#   -n, --no-color     Disable colored output (for basic terminals).
#   -f, --forensic     Forensic mode: don't write any files (implies -v).
#
# Example calls:
#   ./verificile.sh /path/to/directory
#   ./verificile.sh -i -r /path/to/dir1 /path/to/dir2
#   ./verificile.sh -f /path/to/readonly/dir  # Forensic mode
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Set up timestamp for file naming
# -----------------------------------------------------------------------------
DATESTAMP=$(date '+%Y%m%d_%H%M%S')

# -----------------------------------------------------------------------------
# ANSI color codes for styling output (will be disabled with --no-color)
# -----------------------------------------------------------------------------
USE_COLOR=true
RESET="\033[0m"
BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED_BOLD="\033[1;31m"
GREEN="\033[32m"
MAGENTA="\033[35m"
BLUE="\033[34m"
WHITE="\033[37m"

# Function to disable colors if requested
disable_colors() {
    RESET=""
    BOLD=""
    CYAN=""
    YELLOW=""
    RED_BOLD=""
    GREEN=""
    MAGENTA=""
    BLUE=""
    WHITE=""
}

# -----------------------------------------------------------------------------
# Print usage to the console
# -----------------------------------------------------------------------------
usage() {
    echo "Verificile - A tool to verify file extensions match their MIME types"
    echo
    echo "Usage: $0 [OPTIONS] <directory> [<directory>...]"
    echo "  <directory>: One or more directories to check."
    echo "  OPTIONS:"
    echo "    -i, --interactive  Interactive mode: fix anomalies as they're found."
    echo "    -r, --recursive    Recursively check subdirectories."
    echo "    -v, --verbose      Output anomalies to console when found (fixed-width format)."
    echo "    --debug            Enable debug mode to show detailed processing steps."
    echo "    -n, --no-color     Disable colored output (for basic terminals)."
    echo "    -f, --forensic     Forensic mode: don't write any files (implies -v)."
    exit 1
}

# -----------------------------------------------------------------------------
# Function to get unique filename with numeric suffix if needed
# -----------------------------------------------------------------------------
get_unique_filename() {
    local base_filename="$1"
    
    # If file doesn't exist, return the original name
    if [[ ! -e "$base_filename" ]]; then
        echo "$base_filename"
        return
    fi
    
    # Extract components for adding suffix
    local dir_name=$(dirname "$base_filename")
    local file_name=$(basename "$base_filename")
    local name_part
    local ext_part
    
    # Split filename into name and extension
    if [[ "$file_name" == *.* ]]; then
        name_part="${file_name%.*}"
        ext_part=".${file_name##*.}"
    else
        name_part="$file_name"
        ext_part=""
    fi
    
    # Try numeric suffixes until we find an available filename
    local counter=1
    while [[ $counter -lt 1000 ]]; do
        # Format with leading zeros
        local suffix=$(printf "_%03d" $counter)
        local new_name="${dir_name}/${name_part}${suffix}${ext_part}"
        
        if [[ ! -e "$new_name" ]]; then
            echo "$new_name"
            return
        fi
        
        ((counter++))
    done
    
    # If we get here, we ran out of tries
    echo ""
}

# -----------------------------------------------------------------------------
# Parse command-line arguments
# -----------------------------------------------------------------------------
RECURSIVE=false
DEBUG=false
VERBOSE=false
INTERACTIVE=false
FORENSIC=false
DIRECTORIES=()

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        -n|--no-color)
            USE_COLOR=false
            shift
            ;;
        -f|--forensic)
            FORENSIC=true
            VERBOSE=true  # Forensic mode implies verbose
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            DIRECTORIES+=("$1")
            shift
            ;;
    esac
done

# Disable colors if requested
if ! $USE_COLOR; then
    disable_colors
fi

# Ensure at least one directory is specified
if [[ "${#DIRECTORIES[@]}" -eq 0 ]]; then
    usage
fi

# -----------------------------------------------------------------------------
# Fixed column widths for verbose output
# -----------------------------------------------------------------------------
MIME_WIDTH=25      # Width for MIME type column
EXT_WIDTH=8        # Width for actual extension column
EXPECTED_WIDTH=15  # Width for expected extensions column

# -----------------------------------------------------------------------------
# Prepare the TSV file for anomaly reporting
# -----------------------------------------------------------------------------
# Get current date and time
TIMESTAMP="2025-05-15 21:31:37"  # From provided UTC time
USERNAME="thinko"                # From provided username

# Define file paths with timestamps
TSV_BASENAME="verificile_anomalies_${DATESTAMP}.tsv"
RENAME_LOG_BASENAME="verificile_renamed_${DATESTAMP}.log"

# Get unique filenames for outputs
if ! $FORENSIC; then
    TSV_FILE=$(get_unique_filename "$TSV_BASENAME")
    RENAME_LOG=$(get_unique_filename "$RENAME_LOG_BASENAME")
    
    # Create/overwrite the TSV file with a header row and metadata
    echo -e "# Generated by Verificile on $TIMESTAMP by $USERNAME" > "$TSV_FILE"
    echo -e "File Path\tMIME Type\tActual Extension\tExpected Extensions" >> "$TSV_FILE"
else
    # In forensic mode, we don't create files
    TSV_FILE="/dev/null"
    RENAME_LOG="/dev/null"
fi

# Create a temporary flag file to track if anomalies were found
ANOMALY_FLAG_FILE=$(mktemp)
echo "false" > "$ANOMALY_FLAG_FILE"

# Create a temporary file to store MIME type suggestions
SUGGESTIONS_FILE=$(mktemp)
# Track unique MIME type suggestions
declare -A SUGGESTION_MAP

# Print verbose header if in verbose mode
if $VERBOSE && ! $DEBUG; then
    echo -e "${BOLD}Anomalies found during processing:${RESET}"
    # Fixed-width header with columns aligned
    printf "${CYAN}%-${MIME_WIDTH}s${RESET} ${YELLOW}%-${EXT_WIDTH}s${RESET} ${MAGENTA}%-${EXPECTED_WIDTH}s${RESET} ${BLUE}%s${RESET}\n" \
           "MIME Type" "Ext" "Expected" "File Path"
    # Separator line with appropriate length
    printf "%${MIME_WIDTH}s %${EXT_WIDTH}s %${EXPECTED_WIDTH}s %s\n" | tr " " "-"
fi

# -----------------------------------------------------------------------------
# Function that maps a MIME type to accepted extensions
# -----------------------------------------------------------------------------
get_expected_extensions() {
    # $1 is the MIME type
    local mime="$1"
    case "$mime" in
        audio/mpeg)                 echo "mp3"      ;;
        audio/x-flac)               echo "flac"     ;;
        application/gzip)           echo "gz"       ;;
        application/pdf)            echo "pdf"      ;;
        application/x-7z-compressed) echo "7z"      ;;
        application/x-rar)          echo "rar"      ;;
        application/x-tar)          echo "tar"      ;;
        application/zip)            echo "zip"      ;;
        image/bmp)                  echo "bmp"      ;;
        image/gif)                  echo "gif"      ;;
        image/jpeg)                 echo "jpg,jpeg" ;;
        image/png)                  echo "png"      ;;
        image/tiff)                 echo "tiff,tif" ;;
        image/webp)                 echo "webp"     ;;
        text/html)                  echo "html,htm" ;;
        text/plain)                 echo "txt,lnk,urls" ;;
        video/3gpp)                 echo "mp4"      ;;
        video/mp4)                  echo "mp4"      ;;
        video/webm)                 echo "webm"     ;;
        video/x-m4v)                echo "mp4"      ;;
        video/x-matroska)           echo "mkv"      ;;
        *)
            # Default to empty for unknown MIME types
            echo ""
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Function to find a non-colliding filename by adding a suffix
# -----------------------------------------------------------------------------
find_available_filename() {
    local original_path="$1"
    local expected_ext="$2"
    
    # Extract directory and filename components
    local dir_path=$(dirname "$original_path")
    local base_name=$(basename "$original_path")
    
    # Extract name without extension
    local name_part
    if [[ "$base_name" == *.* ]]; then
        name_part="${base_name%.*}"
    else
        name_part="$base_name"
    fi
    
    # Try with the original name first
    local new_path="$dir_path/$name_part.$expected_ext"
    if [[ ! -e "$new_path" || "$new_path" == "$original_path" ]]; then
        echo "$new_path"
        return
    fi
    
    # Start adding numeric suffixes
    local counter=1
    while [[ $counter -lt 1000 ]]; do
        # Format with leading zeros
        local suffix=$(printf "_%03d" $counter)
        new_path="$dir_path/$name_part$suffix.$expected_ext"
        
        # If this path doesn't exist, we found an available name
        if [[ ! -e "$new_path" ]]; then
            echo "$new_path"
            return
        fi
        
        ((counter++))
    done
    
    # If we get here, we couldn't find an available name
    echo ""
}

# -----------------------------------------------------------------------------
# Function to handle interactive fixing of anomalies
# -----------------------------------------------------------------------------
fix_anomaly_interactively() {
    local file_path="$1"
    local actual_ext="$2"
    local expected_exts="$3"
    
    # If we're in forensic mode, just display info but don't allow renaming
    if $FORENSIC; then
        echo -e "\n${BOLD}${YELLOW}Anomaly found:${RESET} $file_path"
        echo -e "${CYAN}Current extension:${RESET} ${RED_BOLD}$actual_ext${RESET}"
        echo -e "${CYAN}Expected extension(s):${RESET} ${GREEN}$expected_exts${RESET}"
        echo -e "${MAGENTA}[FORENSIC MODE] No file modifications allowed${RESET}\n"
        return 1
    }
    
    # Get the first expected extension (if multiple are provided)
    local primary_ext
    IFS=',' read -r primary_ext _ <<< "$expected_exts"
    
    # Extract directory and filename components
    local dir_path=$(dirname "$file_path")
    local base_name=$(basename "$file_path")
    
    # Get the name without extension
    local name_part
    if [[ "$base_name" == *.* ]]; then
        name_part="${base_name%.*}"
    else
        name_part="$base_name"
    fi
    
    echo -e "\n${BOLD}${YELLOW}Fix anomaly:${RESET} $file_path"
    echo -e "${CYAN}Current extension:${RESET} ${RED_BOLD}$actual_ext${RESET}"
    echo -e "${CYAN}Expected extension(s):${RESET} ${GREEN}$expected_exts${RESET}"
    echo
    echo -e "${WHITE}Choose action:${RESET}"
    echo -e "  ${BOLD}1)${RESET} Fix extension (change to '$primary_ext') ${YELLOW}[default]${RESET}"
    echo -e "  ${BOLD}2)${RESET} Skip this file"
    echo -e "  ${BOLD}3)${RESET} Append extension (result: '$base_name.$primary_ext')"
    echo -e "  ${BOLD}4)${RESET} Custom rename (edit filename)"
    
    # Read user input with proper prompt
    local choice
    read -p "Enter choice [1-4]: " choice </dev/tty
    
    # Default to option 1 if no input
    choice=${choice:-1}
    
    local new_path=""
    local action_desc=""
    
    case $choice in
        1)  # Fix extension
            new_path="$dir_path/$name_part.$primary_ext"
            action_desc="Changing extension to '$primary_ext'"
            ;;
        2)  # Skip
            echo -e "${YELLOW}Skipping this file.${RESET}"
            return 1
            ;;
        3)  # Append extension
            new_path="$file_path.$primary_ext"
            action_desc="Appending extension '.$primary_ext'"
            ;;
        4)  # Custom rename
            echo -e "${CYAN}Current filename:${RESET} $base_name"
            echo -e "${YELLOW}Enter new filename (will be saved in same directory):${RESET}"
            local new_name
            read -p "> " new_name </dev/tty
            
            # If user provided a name, use it; otherwise keep the original
            if [[ -n "$new_name" ]]; then
                new_path="$dir_path/$new_name"
                action_desc="Renaming to '$new_name'"
            else
                echo -e "${YELLOW}No new name provided. Skipping this file.${RESET}"
                return 1
            fi
            ;;
        *)  # Invalid choice
            echo -e "${RED_BOLD}Invalid choice. Skipping this file.${RESET}"
            return 1
            ;;
    esac
    
    # Check if the target file already exists (collision detection)
    if [[ -e "$new_path" && "$new_path" != "$file_path" ]]; then
        echo -e "\n${RED_BOLD}Warning:${RESET} Target file already exists: $new_path"
        echo -e "${WHITE}Choose action:${RESET}"
        echo -e "  ${BOLD}1)${RESET} Auto-rename with suffix ${YELLOW}[default]${RESET}"
        echo -e "  ${BOLD}2)${RESET} Custom rename (edit filename)"
        echo -e "  ${BOLD}3)${RESET} Overwrite existing file"
        echo -e "  ${BOLD}4)${RESET} Skip fixing this file"
        
        local collision_choice
        read -p "Enter choice [1-4]: " collision_choice </dev/tty
        
        # Default to option 1 if no input
        collision_choice=${collision_choice:-1}
        
        case $collision_choice in
            1)  # Auto-rename with suffix
                # Extract the extension from new_path
                local target_ext
                if [[ "$new_path" == *.* ]]; then
                    target_ext="${new_path##*.}"
                else
                    target_ext=""
                fi
                
                # Find an available filename with suffix
                new_path=$(find_available_filename "$file_path" "$target_ext")
                
                if [[ -z "$new_path" ]]; then
                    echo -e "${RED_BOLD}Error:${RESET} Could not find an available filename. Skipping."
                    return 1
                fi
                
                action_desc="Auto-renaming to '$(basename "$new_path")'"
                ;;
            2)  # Custom rename
                echo -e "${CYAN}Current target filename:${RESET} $(basename "$new_path")"
                echo -e "${YELLOW}Enter new filename (will be saved in same directory):${RESET}"
                local custom_name
                read -p "> " custom_name </dev/tty
                
                # If user provided a name, use it; otherwise skip
                if [[ -n "$custom_name" ]]; then
                    new_path="$dir_path/$custom_name"
                    action_desc="Custom renaming to '$custom_name'"
                    
                    # Check if this new name also exists
                    if [[ -e "$new_path" && "$new_path" != "$file_path" ]]; then
                        echo -e "${RED_BOLD}Error:${RESET} This filename also exists. Skipping."
                        return 1
                    fi
                else
                    echo -e "${YELLOW}No new name provided. Skipping this file.${RESET}"
                    return 1
                fi
                ;;
            3)  # Overwrite
                action_desc="Overwriting existing file '$(basename "$new_path")'"
                ;;
            4)  # Skip
                echo -e "${YELLOW}Skipping this file.${RESET}"
                return 1
                ;;
            *)  # Invalid choice
                echo -e "${RED_BOLD}Invalid choice. Skipping this file.${RESET}"
                return 1
                ;;
        esac
    fi
    
    # Perform the rename
    echo -e "${CYAN}$action_desc${RESET}"
    echo -e "Renaming: $file_path ${YELLOW}→${RESET} $new_path"
    
    # Confirm before proceeding
    local confirm
    read -p "Proceed? [Y/n]: " confirm </dev/tty
    
    # Default to Yes if no input
    confirm=${confirm:-Y}
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if $FORENSIC; then
            echo -e "${MAGENTA}[FORENSIC MODE] Would rename file but not actually doing it.${RESET}"
            return 1
        elif mv "$file_path" "$new_path"; then
            echo -e "${GREEN}Success!${RESET} File renamed."
            # Add an entry to the renamed_file file to track this fix
            if [[ "$RENAME_LOG" != "/dev/null" ]]; then
                echo "$(date '+%Y-%m-%d %H:%M:%S') - $file_path fixed by renaming to $new_path" >> "$RENAME_LOG"
            fi
            return 0  # Return success
        else
            echo -e "${RED_BOLD}Error:${RESET} Failed to rename file."
            return 1  # Return failure
        fi
    else
        echo -e "${YELLOW}Operation cancelled.${RESET}"
        return 1  # Return failure (did not fix)
    fi
    
    echo  # Add a blank line for readability
}

# -----------------------------------------------------------------------------
# Process each file, checking MIME type vs extension
# -----------------------------------------------------------------------------
process_file() {
    local FILE="$1"
    
    # Skip processing the TSV file itself
    if [[ -n "$TSV_FILE" && "$FILE" == "$TSV_FILE" ]]; then
        if $DEBUG; then
            echo -e "${CYAN}Skipping TSV file:${RESET} ${YELLOW}$FILE${RESET}\n"
        fi
        return
    fi
    
    # Skip processing the rename log file
    if [[ -n "$RENAME_LOG" && "$FILE" == "$RENAME_LOG" ]]; then
        if $DEBUG; then
            echo -e "${CYAN}Skipping log file:${RESET} ${YELLOW}$FILE${RESET}\n"
        fi
        return
    fi

    # Debug: show we are processing this file
    if $DEBUG; then
        echo -e "${CYAN}Processing file:${RESET} ${YELLOW}$FILE${RESET}"
    fi

    # Detect MIME type using the `file` command
    MIME_TYPE=$(file --mime-type -b "$FILE")
    if $DEBUG; then
        echo -e "  ${CYAN}Detected MIME type:${RESET} ${YELLOW}$MIME_TYPE${RESET}"
    fi

    # Extract the file extension (lowercase) based on the last dot in the basename
    BASENAME=$(basename "$FILE")
    if [[ "$BASENAME" == .* ]]; then
        # Files starting with a dot, e.g. ".hidden" or ".png"
        if [[ "$BASENAME" == *.* ]]; then
            # e.g. ".myfile.png" → extension "png"
            ACTUAL_EXTENSION=$(echo "$BASENAME" | awk -F. '{print tolower($NF)}')
        else
            # e.g. ".hiddenfile" → no extension
            ACTUAL_EXTENSION=""
        fi
    elif [[ "$BASENAME" == *.* ]]; then
        # Regular files with a dot
        ACTUAL_EXTENSION=$(echo "$BASENAME" | awk -F. '{print tolower($NF)}')
    else
        # Filename with no dot
        ACTUAL_EXTENSION=""
    fi

    if $DEBUG; then
        echo -e "  ${CYAN}Actual file extension:${RESET} ${YELLOW}$ACTUAL_EXTENSION${RESET}"
    fi

    # Get the valid extensions for the MIME type
    EXPECTED_EXTENSIONS=$(get_expected_extensions "$MIME_TYPE")

    if $DEBUG; then
        echo -e "  ${CYAN}Expected extensions:${RESET} ${YELLOW}$EXPECTED_EXTENSIONS${RESET}"
    fi

    # Determine if the extension matches any expected extension
    MATCH_FOUND=false
    if [[ -n "$EXPECTED_EXTENSIONS" ]]; then
        IFS=',' read -ra EXT_ARRAY <<< "$EXPECTED_EXTENSIONS"
        for EXT in "${EXT_ARRAY[@]}"; do
            if [[ "$ACTUAL_EXTENSION" == "$EXT" ]]; then
                MATCH_FOUND=true
                break
            fi
        done
    elif [[ -n "$ACTUAL_EXTENSION" ]]; then
        # This is a new MIME type - add it to suggestions if extension seems correct
        # Check if we've already seen this MIME type + extension combination
        local SUGGESTION_KEY="${MIME_TYPE}:${ACTUAL_EXTENSION}"
        if [[ -z "${SUGGESTION_MAP[$SUGGESTION_KEY]}" ]]; then
            SUGGESTION_MAP[$SUGGESTION_KEY]=1
            # Generate suggestion line for the get_expected_extensions function
            echo -e "${MIME_TYPE}\t${ACTUAL_EXTENSION}\t${FILE}" >> "$SUGGESTIONS_FILE"
        fi
        
        # Don't count these as anomalies
        if $DEBUG; then
            echo -e "  ${MAGENTA}New MIME type detected with possible matching extension.${RESET}\n"
        fi
        return
    fi

    # If no match was found, record the anomaly
    if ! $MATCH_FOUND; then
        # Set the flag file to indicate anomalies were found
        echo "true" > "$ANOMALY_FLAG_FILE"
        
        # Handle the anomaly based on mode
        if $INTERACTIVE; then
            # Interactive mode: ask user how to fix the anomaly
            local fixed=false
            fix_anomaly_interactively "$FILE" "$ACTUAL_EXTENSION" "$EXPECTED_EXTENSIONS"
            fixed=$?
            
            # If the file still exists and wasn't fixed, add it to the TSV file
            if [[ -e "$FILE" && $fixed -ne 0 ]]; then
                echo -e "$FILE\t$MIME_TYPE\t$ACTUAL_EXTENSION\t$EXPECTED_EXTENSIONS" >> "$TSV_FILE"
            fi
        else
            # Non-interactive mode: just record the anomaly
            echo -e "$FILE\t$MIME_TYPE\t$ACTUAL_EXTENSION\t$EXPECTED_EXTENSIONS" >> "$TSV_FILE"
            
            if $VERBOSE; then
                if $DEBUG; then
                    # If also in debug mode, show anomaly as part of the debug output
                    echo -e "  ${RED_BOLD}Anomaly detected!${RESET} ${YELLOW}$ACTUAL_EXTENSION${RESET} should be ${MAGENTA}$EXPECTED_EXTENSIONS${RESET}"
                    echo ""
                else
                    # In verbose-only mode, show fixed-width formatted output
                    # Truncate actual extension to EXT_WIDTH characters if needed
                    TRUNCATED_EXT="${ACTUAL_EXTENSION:0:$EXT_WIDTH}"
                    
                    # Format the output with fixed column widths, file path is last and can wrap
                    printf "${CYAN}%-${MIME_WIDTH}s${RESET} ${YELLOW}%-${EXT_WIDTH}s${RESET} ${MAGENTA}%-${EXPECTED_WIDTH}s${RESET} ${BLUE}%s${RESET}\n" \
                           "$MIME_TYPE" "$TRUNCATED_EXT" "$EXPECTED_EXTENSIONS" "$FILE"
                fi
            elif $DEBUG; then
                # Original debug output if not in verbose mode
                echo -e "  ${RED_BOLD}Anomaly detected!${RESET}\n"
            fi
        fi
    elif $DEBUG; then
        # Print a blank line after each file in debug mode
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Iterate over directories and run either a recursive or non-recursive find
# -----------------------------------------------------------------------------
for DIRECTORY in "${DIRECTORIES[@]}"; do
    if [[ ! -d "$DIRECTORY" ]]; then
        echo "Directory not found: $DIRECTORY"
        continue
    fi

    if $RECURSIVE; then
        # Recursively process files using process substitution to avoid subshell issues
        while IFS= read -r -d '' FILE; do
            process_file "$FILE"
        done < <(find "$DIRECTORY" -type f -print0)
    else
        # Non-recursive process
        while IFS= read -r -d '' FILE; do
            process_file "$FILE"
        done < <(find "$DIRECTORY" -maxdepth 1 -type f -print0)
    fi
done

# Add a separator after verbose output
if $VERBOSE && ! $DEBUG; then
    # Print separator with appropriate length
    printf "%${MIME_WIDTH}s %${EXT_WIDTH}s %${EXPECTED_WIDTH}s %s\n" | tr " " "-"
fi

# -----------------------------------------------------------------------------
# Display suggested additions to get_expected_extensions function
# -----------------------------------------------------------------------------
if [[ -s "$SUGGESTIONS_FILE" ]]; then
    echo -e "\n${BOLD}Suggested additions to get_expected_extensions() function:${RESET}"
    echo "Add the following case statements to support new MIME types:"
    echo -e "${CYAN}------------------------------------------------------${RESET}"
    
    while IFS=$'\t' read -r MIME_TYPE EXT EXAMPLE_FILE; do
        echo -e "${CYAN}${MIME_TYPE})${RESET}\t\techo \"${YELLOW}${EXT}${RESET}\" ;; ${MAGENTA}# From: $(basename "$EXAMPLE_FILE")${RESET}"
    done < "$SUGGESTIONS_FILE"
    
    echo -e "${CYAN}------------------------------------------------------${RESET}"
    echo ""
fi

# -----------------------------------------------------------------------------
# Check if any anomalies remain in the TSV file (besides headers)
# -----------------------------------------------------------------------------
# Count the number of data lines in the TSV file (exclude header lines)
if [[ -f "$TSV_FILE" && "$TSV_FILE" != "/dev/null" ]]; then
    ANOMALY_COUNT=$(grep -v '^#' "$TSV_FILE" | grep -v '^File Path' | wc -l)

    # If all anomalies were fixed (only headers in the TSV), set FOUND_ANOMALIES to false
    if [[ $ANOMALY_COUNT -eq 0 ]]; then
        echo "false" > "$ANOMALY_FLAG_FILE"
        if $DEBUG; then
            echo -e "${GREEN}All anomalies have been fixed!${RESET}"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------------
# Read the anomaly flag
FOUND_ANOMALIES=$(cat "$ANOMALY_FLAG_FILE")

# Clean up temporary files
rm "$ANOMALY_FLAG_FILE" "$SUGGESTIONS_FILE" 2>/dev/null

if [[ "$FOUND_ANOMALIES" == "true" ]]; then
    if $FORENSIC; then
        echo -e "${BOLD}Anomalies detected!${RESET} ${MAGENTA}[FORENSIC MODE] Results not saved to file.${RESET}"
    else
        echo -e "${BOLD}Anomalies detected!${RESET} See the list in ${BOLD}$TSV_FILE${RESET}"
        echo -e "Report generated on ${CYAN}$TIMESTAMP${RESET} by user ${CYAN}$USERNAME${RESET}"
    fi
else
    echo -e "${GREEN}No anomalies detected. All file extensions match their MIME types.${RESET}"
    # Remove the anomalies file if none were found and we're not in forensic mode
    if [[ -f "$TSV_FILE" && "$TSV_FILE" != "/dev/null" ]]; then
        rm "$TSV_FILE" 2>/dev/null
    fi
fi

# Show summary of file operations if not in forensic mode and changes were made
if [[ -f "$RENAME_LOG" && "$RENAME_LOG" != "/dev/null" && -s "$RENAME_LOG" ]]; then
    RENAME_COUNT=$(wc -l < "$RENAME_LOG")
    echo -e "\n${BOLD}File operations:${RESET} ${GREEN}$RENAME_COUNT${RESET} files renamed (see ${BOLD}$RENAME_LOG${RESET} for details)"
fi

# If in forensic mode, note that no files were written
if $FORENSIC; then
    echo -e "${MAGENTA}[FORENSIC MODE] No files were created or modified.${RESET}"
fi