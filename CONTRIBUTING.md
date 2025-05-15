# Contributing to Verificile

Thank you for your interest in contributing to Verificile! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project.

## How Can I Contribute?

### Reporting Bugs

When reporting bugs, please include:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs. actual behavior
- System information (OS, Bash version, etc.)
- Any relevant error messages or screenshots

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- A clear description of the enhancement
- The motivation behind it
- Any potential implementation approaches you might suggest

### Pull Requests

1. Fork the repository
2. Create a new branch for your feature or bugfix
3. Make your changes
4. Test your changes thoroughly
5. Submit a pull request with a clear description of the changes

## Development Guidelines

### Adding MIME Type Support

If you're adding support for new MIME types, please add them to the `get_expected_extensions()` function in alphabetical order, and include a comment with an example file type.

Example:
```bash
application/x-new-type)   echo "nt"      ;; # New Type Format