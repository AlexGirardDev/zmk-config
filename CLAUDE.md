# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal ZMK (Zephyr Mechanical Keyboard) firmware configuration repository that builds against ZMK v0.2. It features a 34-key base layout reused across multiple keyboard boards including Corneish Zen, Planck, and various shields. The configuration emphasizes advanced features like "timeless" homerow mods, smart layers, combos, and leader keys.

## Build System & Commands

### Development Environment Setup
The project uses a Nix-based development environment with `direnv` and `just` for build automation:

```bash
# Initialize workspace (first time)
just init

# Build all firmware targets
just build all

# Build specific target (e.g., Corneish Zen)
just build zen

# Clean build artifacts
just clean

# Update ZMK dependencies
just update

# Generate keymap diagram
just draw
```

### Build Targets
Build targets are defined in `build.yaml` and include:
- `adv360_left/right` - ADV360 keyboard halves
- `corne_left/right` - Corne shields with nice_nano_v2
- `urchin_left/right` - Urchin shields with nice_nano_v2
- `corneish_zen_v2_left/right` - Corneish Zen v2 boards
- `totem_left/right` - Totem shields with seeeduino_xiao_ble

### Testing
```bash
# Run specific test
just test <path_to_test> [flags]

# Available flags: --no-build, --verbose, --auto-accept
```

## Architecture & Key Components

### Core Configuration Files

#### `config/base.keymap`
- Main keymap definition with 8 layers: DEF, NAV, NUM, FN, SYS, SYMBOL, MOUSE, GAME
- Includes advanced homerow mods configuration with "timeless" behavior
- Uses ZMK helper macros for cleaner syntax

#### `config/combos.dtsi`
- Comprehensive combo definitions for symbols and shortcuts
- Homerow combos with tap-only behavior to work with HRMs
- System combos for bootloader access and layer switching

#### `config/leader.dtsi`
- Leader key sequences for German umlauts, Greek letters, and system commands
- Activated via combo (S + T keys)

#### `config/mouse.dtsi`
- Mouse movement and scrolling configuration
- Tuned for high-resolution displays (3840x2160)

#### Board-Specific Configuration Files
- `config/{board}.conf` - Board-specific settings for different keyboards
- `config/{board}.keymap` - Board-specific keymap overrides when needed

### ZMK Modules & Extensions
Located in `modules/zmk/`:
- **adaptive-key**: Advanced key behavior adaptation
- **auto-layer**: Smart layer activation (used for Numword feature)
- **helpers**: Macro system for cleaner devicetree syntax
- **leader-key**: Leader key sequence implementation
- **tri-state**: One-handed Alt-Tab switcher functionality

Local modules in `modules/local/`:
- **zmk-behavior-turbo-key**: Custom turbo key behavior

### West Workspace Structure
Defined in `config/west.yml`:
```
zmk-workspace/
├── config/          # User configuration (this repo)
├── modules/         # ZMK modules and extensions  
├── zephyr/          # Zephyr RTOS (pinned to v3.5.0+zmk-fixes)
└── zmk/             # Main ZMK firmware
```

## Key Features Implementation

### Homerow Mods ("Timeless")
- Uses `balanced` flavor with large tapping-term (280ms)
- `require-prior-idle-ms` (150ms) eliminates typing delays
- Positional hold-tap prevents same-hand false positives
- `hold-trigger-on-release` allows modifier combinations

### Smart Layers
- **Numword**: Auto-activating number layer that stays active during number entry
- **Smart-Mouse**: Automatic mouse layer with scroll and movement
- **Magic Repeat/Shift/Capsword**: Multi-function right thumb key

### Build Environment
- Nix flake provides isolated development environment
- Automated dependency management with pinned versions
- Cross-platform support (Linux, macOS, both x86_64 and ARM64)

## Development Workflow

### Making Changes
1. Edit keymap files in `config/`
2. Test build with `just build <target>`
3. Flash firmware files from `firmware/` directory
4. Use `just draw` to visualize keymap changes

### Adding New Boards
1. Add board/shield combinations to `build.yaml`
2. Create board-specific `.conf` file in `config/`
3. Optionally create board-specific `.keymap` file

### Working with Modules
- ZMK modules are managed via `config/west.yml`
- Local modules can be added to `modules/local/`
- Update modules with `just update`

## Testing & Validation

### Combo Configuration Parsing
The build system automatically parses `combos.dtsi` to set optimal ZMK configuration:
- `CONFIG_ZMK_COMBO_MAX_COMBOS_PER_KEY`
- `CONFIG_ZMK_COMBO_MAX_KEYS_PER_COMBO`

### Linting & Type Checking
No specific linting commands are configured. The ZMK build process itself validates devicetree syntax and configuration.

## Common Development Tasks

### Troubleshooting Builds
- Use `just build <target> -p` for pristine builds
- Check `CONFIG_ZMK_*` settings in `.conf` files
- Verify module versions in `config/west.yml`

### Keymap Visualization
- `just draw` generates SVG diagrams
- Configuration in `draw/config.yaml`
- Output files: `draw/base.svg` and `draw/base.yaml`

### Environment Management  
- `just upgrade-sdk` updates Nix packages (use with caution)
- `just clean-nix` clears Nix cache
- Environment is pinned via `flake.lock` for reproducibility