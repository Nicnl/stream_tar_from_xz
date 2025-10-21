# stream_tar_from_xz

A Go utility that walks a directory tree and streams a tar archive, while uncompressing XZ on-the-fly.   
Useful for injecting thar flat tar into a deduplicating backup system such as Borg or Restic.

## Features

- Recursively processes directories
- Automatically decompresses `.xz` files while streaming to tar
- Copies non-compressed files as-is
- The tar is fully streamed without using disk storage
- Multi-threaded XZ decompression (configurable)
- Outputs to stdout or file

## Requirements

- Go 1.x or later (for building)
- `xz` utility must be installed and available in PATH

## Installation

### From source

```bash
make build
sudo make install
```

### Build for specific platforms

```bash
make build-linux-amd64
make build-linux-arm64
make build-windows-amd64
make build-darwin-arm64
# Or build all targets
make all
```

### Package for Linux distributions

```bash
SEMVER=1.0.0 make build-linux-amd64 package-amd64-linux
```

This creates `.deb`, `.rpm`, `.ipk`, and Arch Linux packages in the `dist/` directory.

## Usage

```bash
stream_tar_from_xz <path_to_directory> [optional: output_file]
```

### Examples

Output to stdout:
```bash
stream_tar_from_xz /path/to/dir > output.tar
```

Output to file:
```bash
stream_tar_from_xz /path/to/dir output.tar
```

### Configuration

Set the number of XZ decompression threads via environment variable:
```bash
XZ_NUM_THREADS=4 stream_tar_from_xz /path/to/dir
```

Default: number of CPU cores

## How it works

1. Walks the input directory recursively
2. For `.xz` files: queries uncompressed size, decompresses on-the-fly, and streams to tar without `.xz` extension
3. For other files: copies directly to tar
4. Preserves directory structure and file metadata

## License

See LICENSE file for details.