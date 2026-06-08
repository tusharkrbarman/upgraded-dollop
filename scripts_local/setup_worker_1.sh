#!/bin/bash
# Setup script for Worker 1 (Laptop 4) - Local Network Deployment

set -e

echo "=========================================="
echo "Setting up Worker 1 (Laptop 4)"
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
mkdir -p storage/worker-1
mkdir -p logs
mkdir -p data

# Copy configuration
echo "Setting up configuration..."
cp config_local.yaml config.yaml

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 9999/udp
ufw --force enable

# Set worker ID
export WORKER_ID="worker-1"

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/worker.service <<EOF
[Unit]
Description=Distributed AI Training System - Worker 1
After=network.target

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/projects/distributed-ai-training
Environment="PATH=/home/user/projects/distributed-ai-training/venv/bin"
Environment="PYTHONUNBUFFERED=1"
Environment="WORKER_ID=worker-1"
ExecStart=/home/user/projects/distributed-ai-training/venv/bin/python src/worker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling worker service..."
systemctl daemon-reload
systemctl enable worker.service

echo "=========================================="
echo "Worker 1 setup completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Your IP: 192.168.1.13"
echo "2. Worker ID: worker-1"
echo "3. Worker Type: Fast (will be determined at runtime)"
echo "4. TLS disabled for local network deployment"
echo ""
echo "To start the worker:"
echo "  sudo systemctl start worker"
echo ""
echo "To check status:"
echo "  sudo systemctl status worker"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u worker -f"
echo ""
echo "NEXT STEPS:"
echo "1. Update config.yaml with correct IP addresses"
echo "2. Start Kafka brokers first"
echo "3. Start MongoDB"
echo "4. Then start this worker"
echo "5. Verify worker is consuming messages from Kafka"
