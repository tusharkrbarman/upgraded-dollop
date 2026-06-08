#!/bin/bash
# Setup script for Head Node (Laptop 1) - Local Network Deployment

set -e

echo "=========================================="
echo "Setting up Head Node (Laptop 1)"
echo "Local Network Deployment"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update system
echo "Updating system..."
apt update && apt upgrade -y

# Install Python and pip
echo "Installing Python and pip..."
apt install -y python3 python3-pip python3-venv

# Create project directory
echo "Creating project directory..."
mkdir -p /home/user/projects/distributed-ai-training
cd /home/user/projects/distributed-ai-training

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
cp config_local.yaml config.yaml

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 5000/tcp
ufw --force enable

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/head-node.service <<EOF
[Unit]
Description=Distributed AI Training System - Head Node
After=network.target

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/projects/distributed-ai-training
Environment="PATH=/home/user/projects/distributed-ai-training/venv/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=/home/user/projects/distributed-ai-training/venv/bin/python src/head_node.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling head node service..."
systemctl daemon-reload
systemctl enable head-node.service

echo "=========================================="
echo "Head Node setup completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Your IP: 192.168.1.10"
echo "2. TLS disabled for local network deployment"
echo "3. Firewall configured"
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
echo "API will be available at: http://192.168.1.10:5000"
echo "API Documentation: http://192.168.1.10:5000/docs"
echo ""
echo "NEXT STEPS:"
echo "1. Update config.yaml on other laptops with this laptop's IP"
echo "2. Test connectivity from other laptops"
