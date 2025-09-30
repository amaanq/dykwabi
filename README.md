# Dykwabi

A lightweight CLI tool for managing [BuckMaterialShell](https://github.com/amaanq/BuckMaterialShell), a fork of [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) for [Quickshell](https://quickshell.org/).

## Features

- **Process Management** - Start, stop, and restart your Quickshell instance
- **Daemon Mode** - Run your shell in the background
- **IPC Support** - Send commands to running shell instances
- **Zero Dependencies** - Single statically-linked binary (40KB!)

## Installation

### From Source (Nix)

```bash
nix build github:amaanq/dykwabi
./result/bin/dykwabi --help
```

### From Source (Zig)

Requires Zig 0.15.1+

```bash
git clone https://github.com/amaanq/dykwabi
cd dykwabi
zig build -Doptimize=ReleaseSmall
./zig-out/bin/dykwabi --help
```

## Usage

```bash
# Show help
dykwabi help

# Show version
dykwabi version

# Start shell interactively
dykwabi run

# Start shell as daemon
dykwabi run --daemon
dykwabi run -d

# Restart running shell
dykwabi restart

# Kill running shell processes
dykwabi kill

# Send IPC commands
dykwabi ipc <command> [args...]
```

## Requirements

- [Quickshell](https://github.com/quickshell-mirror/quickshell) - The shell runtime (`qs` binary)
- [BuckMaterialShell](https://github.com/amaanq/BuckMaterialShell) - The shell configuration (installed at `~/.config/quickshell/dykwabi`)
