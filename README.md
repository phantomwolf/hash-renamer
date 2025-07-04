# Hash Renamer
A small Bash script to rename files in a directory based on their checksum values(e.g. to remove duplicated files). You can choose any common hash algorithm (MD5, SHA1, SHA256, …), inject the hash into a filename template, and optionally handle collisions or overwrite.

## Features

- Compute file hashes: `md5sum`, `sha1sum`, `sha224sum`, `sha256sum`, `sha384sum`, `sha512sum`  
- Rename a single file or batch-rename an entire directory  
- Customizable filename pattern (e.g. `%h` → hash, plus sequence numbers on collision)  
- Support for recursive directory traversal or single-level processing  
- Optional overwrite of existing files  
- Hook in extra `find` options (e.g. `-mtime`, `-size`)  

## Usage
./hash-rename.sh <directory> [pattern] [--format FORMAT] [--hash ALGO] [--recursive true|false] [--overwrite true|false] [--find-opts OPTIONS]
