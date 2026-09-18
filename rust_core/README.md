# CipherClean Rust Core

High-performance extension for CipherClean providing:
- Parallel file hashing with SHA256
- Multi-threaded directory scanning
- Optimized memory usage for large datasets

## Building

```bash
# Install maturin
pip install maturin

# Build and install in development mode
maturin develop --release

# Or build a wheel
maturin build --release
```

## Usage in Python

```python
from cipherclean_core import FastHasher, DirScanner

# Fast parallel hashing
hasher = FastHasher()
hash_result = hasher.hash_file("/path/to/file")
hashes = hasher.hash_files_parallel(["/file1", "/file2", "/file3"])

# Fast directory scanning
scanner = DirScanner(max_depth=10, follow_links=False)
files = scanner.scan_directory("/path/to/scan")
files_multi = scanner.scan_directory_parallel(["/path1", "/path2"])
```
