#!/bin/bash
# Setup script for Head Node (VM-1)

set -e

echo "=========================================="
echo "Setting up Head Node (VM-1)"
echo "=========================================="

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install Python and pip
echo "Installing Python and pip..."
sudo apt install -y python3 python3-pip python3-venv

# Install Java (required for Kafka)
echo "Installing Java..."
sudo apt install -y openjdk-11-jdk

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc
source ~/.bashrc

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
mkdir -p storage
mkdir -p logs
mkdir -p data

# Copy configuration
echo "Setting up configuration..."
cp config.yaml ~/projects/distributed-ai-training/

# Create systemd service file
echo "Creating systemd service..."
sudo tee /etc/systemd/system/head-node.service > /dev/null <<EOF
[Unit]
Description=Distributed AI Training System - Head Node
After=network.target

[Service]
Type=simple
User=student
WorkingDirectory=/home/student/projects/distributed-ai-training
Environment="PATH=/home/student/projects/distributed-ai-training/venv/bin"
ExecStart=/home/student/projects/distributed-ai-training/venv/bin/python src/head_node.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling head node service..."
sudo systemctl daemon-reload
sudo systemctl enable head-node.service

echo "=========================================="
echo "Head Node setup completed successfully!"
echo "=========================================="
echo ""
echo "To start the head node:"
echo "  sudo systemctl start head-node"
echo ""
echo "To check status:"
echo "  sudo systemctl status head-node"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u head-node -f"
echo ""
echo "API will be available at: http://192.168.56.10:5000"
echo "API Documentation: http://192.168.56.10:5000/docs"
