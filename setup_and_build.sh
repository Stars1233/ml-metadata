#!/bin/bash
set -e  # Exit on any error

# Configuration
MINIFORGE_DIR="$HOME/miniforge3"
ENV_NAME="ml-metadata-build"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "ML-Metadata Native Build Setup Script"
echo "=========================================="
echo ""

# Step 1: Install Miniforge (includes mamba) if not already installed
if [ ! -d "$MINIFORGE_DIR" ]; then
    echo "Step 1: Installing Miniforge (includes mamba)..."
    cd /tmp

    # Detect architecture
    if [ "$(uname -m)" = "x86_64" ]; then
        MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh"
    elif [ "$(uname -m)" = "aarch64" ]; then
        MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh"
    else
        echo "Unsupported architecture: $(uname -m)"
        exit 1
    fi

    wget "$MINIFORGE_URL" -O miniforge.sh
    bash miniforge.sh -b -p "$MINIFORGE_DIR"
    rm miniforge.sh

    echo "Miniforge installed to $MINIFORGE_DIR"
else
    echo "Step 1: Miniforge already installed at $MINIFORGE_DIR"
fi

# Step 2: Install Bazelisk if not already installed
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

if [ ! -f "$BIN_DIR/bazelisk" ]; then
    echo ""
    echo "Step 2: Installing Bazelisk..."
    cd /tmp

    # Detect architecture
    if [ "$(uname -m)" = "x86_64" ]; then
        BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/download/v1.25.0/bazelisk-linux-amd64"
    elif [ "$(uname -m)" = "aarch64" ]; then
        BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/download/v1.25.0/bazelisk-linux-arm64"
    else
        echo "Unsupported architecture: $(uname -m)"
        exit 1
    fi

    wget "$BAZELISK_URL" -O "$BIN_DIR/bazelisk"
    chmod +x "$BIN_DIR/bazelisk"

    # Create bazel symlink
    ln -sf "$BIN_DIR/bazelisk" "$BIN_DIR/bazel"

    echo "Bazelisk installed to $BIN_DIR/bazelisk"
else
    echo ""
    echo "Step 2: Bazelisk already installed at $BIN_DIR/bazelisk"
fi

# Add to PATH for this session
export PATH="$BIN_DIR:$PATH"

# Set Bazel version to use
export USE_BAZEL_VERSION=6.5.0

# Step 3: Initialize conda/mamba for this shell session
echo ""
echo "Step 3: Initializing mamba..."
source "$MINIFORGE_DIR/etc/profile.d/conda.sh"
source "$MINIFORGE_DIR/etc/profile.d/mamba.sh"

# Step 4: Create environment from environment.yml if it doesn't exist
echo ""
echo "Step 4: Setting up conda environment '$ENV_NAME'..."
if conda env list | grep -q "^$ENV_NAME "; then
    echo "Environment '$ENV_NAME' already exists. Updating it..."
    cd "$SCRIPT_DIR"
    mamba env update -n "$ENV_NAME" -f environment.yml
else
    echo "Creating environment '$ENV_NAME' from environment.yml..."
    cd "$SCRIPT_DIR"
    mamba env create -f environment.yml
fi

# Step 5: Activate the environment
echo ""
echo "Step 5: Activating environment '$ENV_NAME'..."
conda activate "$ENV_NAME"

# Verify environment
echo ""
echo "Environment verification:"
echo "  Python: $(which python) ($(python --version))"
echo "  Bazelisk: $(which bazelisk)"
echo "  CMake: $(cmake --version | head -n1)"
echo "  GCC: $(gcc --version | head -n1)"

# Step 6: Build the wheel
echo ""
echo "Step 6: Building ml-metadata wheel..."
cd "$SCRIPT_DIR"

# Clean previous build artifacts if requested
if [ "$1" = "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    bazel clean
    rm -rf build/ dist/ *.egg-info
fi

# Build the wheel
echo ""
echo "Starting build (this may take several minutes)..."
python setup.py bdist_wheel

# Show results
echo ""
echo "=========================================="
echo "Build completed successfully!"
echo "=========================================="
echo ""
echo "Wheel file(s):"
ls -lh dist/*.whl
echo ""
echo "To install the wheel:"
echo "  pip install dist/ml_metadata-*.whl"
echo ""
echo "To rebuild in the future:"
echo "  1. export PATH=\$HOME/.local/bin:\$PATH"
echo "  2. source $MINIFORGE_DIR/etc/profile.d/conda.sh"
echo "  3. conda activate $ENV_NAME"
echo "  4. python setup.py bdist_wheel"
echo ""
