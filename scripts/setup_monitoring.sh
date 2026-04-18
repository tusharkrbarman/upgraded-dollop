#!/bin/bash
# Setup script for Monitoring Service (VM-8)

set -e

echo "=========================================="
echo "Setting up Monitoring Service (VM-8)"
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
mkdir -p logs
mkdir -p data

# Copy configuration
echo "Setting up configuration..."
cp config.yaml ~/projects/distributed-ai-training/

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/monitoring.service > /dev/null <<EOF
[Unit]
Description=Distributed AI Training System - Monitoring Service
After=network.target

[Service]
Type=simple
User=student
WorkingDirectory=/home/student/projects/distributed-ai-training
Environment="PATH=/home/student/projects/distributed-ai-training/venv/bin"
ExecStart=/home/student/projects/distributed-ai-training/venv/bin/python src/monitoring.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling monitoring service..."
sudo systemctl daemon-reload
sudo systemctl enable monitoring.service

echo "=========================================="
echo "Monitoring Service setup completed successfully!"
echo "=========================================="
echo ""
echo "To start the monitoring service:"
echo "  sudo systemctl start monitoring"
echo ""
echo "To check status:"
echo "  sudo systemctl status monitoring"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u monitoring -f"
echo ""
echo "Monitoring service listening on port 9999"
