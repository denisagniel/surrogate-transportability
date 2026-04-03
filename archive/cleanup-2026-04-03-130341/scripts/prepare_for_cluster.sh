#!/bin/bash
# Prepare code for transfer to Slurm cluster

echo "=========================================="
echo "Preparing for Cluster Transfer"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "SLURM_INSTRUCTIONS.md" ]; then
    echo "ERROR: Run this script from the project root directory"
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p slurm/logs
echo "✓ Created slurm/logs directory"

# Prompt for email address
echo ""
read -p "Enter your email address for job notifications: " EMAIL

if [ -z "$EMAIL" ]; then
    echo "Warning: No email provided. You'll need to edit .slurm files manually."
else
    # Update email in all slurm scripts
    sed -i.bak "s/your.email@example.com/$EMAIL/g" slurm/*.slurm
    echo "✓ Updated email address in slurm scripts"
    rm -f slurm/*.slurm.bak
fi

# Create transfer directory
TRANSFER_DIR="surrogate-transportability-cluster"
rm -rf "$TRANSFER_DIR"
mkdir -p "$TRANSFER_DIR"

echo ""
echo "Creating clean transfer directory..."

# Copy necessary files
rsync -av --exclude='.git' \
          --exclude='*.pdf' \
          --exclude='*.Rhistory' \
          --exclude='.Rproj.user' \
          --exclude='*.rds' \
          --exclude='methods/main_backup*' \
          --exclude='explorations/' \
          ./ "$TRANSFER_DIR/"

echo "✓ Created $TRANSFER_DIR"

# Create archive
echo ""
echo "Creating tar.gz archive..."
tar -czf surrogate-transportability-cluster.tar.gz "$TRANSFER_DIR"
echo "✓ Created surrogate-transportability-cluster.tar.gz"

# Get file size
SIZE=$(du -h surrogate-transportability-cluster.tar.gz | cut -f1)

echo ""
echo "=========================================="
echo "Ready for Transfer"
echo "=========================================="
echo ""
echo "Archive: surrogate-transportability-cluster.tar.gz"
echo "Size: $SIZE"
echo ""
echo "Transfer to cluster:"
echo "  scp surrogate-transportability-cluster.tar.gz username@cluster.edu:~/"
echo ""
echo "Or use rsync directly:"
echo "  rsync -avz $TRANSFER_DIR/ username@cluster.edu:~/surrogate-transportability/"
echo ""
echo "On cluster:"
echo "  tar -xzf surrogate-transportability-cluster.tar.gz"
echo "  cd $TRANSFER_DIR"
echo "  sbatch slurm/studies_quick_test.slurm"
echo ""
echo "See SLURM_INSTRUCTIONS.md for complete documentation"
