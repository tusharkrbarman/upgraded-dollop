#!/bin/bash
# Setup script for Worker 1 (VM-4) - Fast Worker

set -e

echo "=========================================="
echo "Setting up Worker 1 (VM-4) - Fast Worker"
echo "=========================================="

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install Python and pip
echo "Installing Python and pip..."
sudo apt install -y python3 python3-pip python3-venv

# Create project directory
echo "Creating project directory..."
mkdir -p ~/projects/distributed-ai-training
cd ~/projects/distributed-ai-training

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
echo "Creating directories..."
mkdir -p storage/worker-1
mkdir -p logs
mkdir -p data

# Copy configuration
echo "Setting up configuration..."
cp config.yaml ~/projects/distributed-ai-training/

# Set worker ID
export WORKER_ID="worker-1"

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/worker.service > /dev/null <<EOF
[Unit]
Description=Distributed AI Training System - Worker 1
After=network.target

[Service]
Type=simple
User=student
WorkingDirectory=/home/student/projects/distributed-ai-training
Environment="PATH=/home/student/projects/distributed-ai-training/venv/bin"
Environment="WORKER_ID=worker-1"
ExecStart=/home/student/projects/distributed-ai-training/venv/bin/python src/worker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling worker service..."
sudo systemctl daemon-reload
sudo systemctl enable worker.service

echo "=========================================="
echo "Worker 1 setup completed successfully!"
echo "=========================================="
echo ""
echo "To start the worker:"
echo "  sudo systemctl start worker"
echo ""
echo "To check status:"
echo "  sudo systemctl status worker"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u worker -f"
