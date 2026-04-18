#!/bin/bash
# Setup script for Worker 2 (Laptop 5) - Local Network Deployment

set -e

echo "=========================================="
echo "Setting up Worker 2 (Laptop 5)"
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
mkdir -p storage/worker-2
mkdir -p logs
mkdir -p data
mkdir -p /etc/ssl/certs

# Copy configuration
echo "Setting up configuration..."
cp config_local.yaml config.yaml

# Setup SSL certificates
echo "Setting up SSL certificates..."
mkdir -p ~/ssl-certs
cd ~/ssl-certs

# Check if certificates already exist
if [ ! -f "ca.pem" ]; then
    echo "Certificates not found. Please copy certificates from Head Node (Laptop 1):"
    echo "  scp user@192.168.1.10:~/ssl-certs/ca.pem ~/ssl-certs/"
    echo "  scp user@192.168.1.10:~/ssl-certs/client-cert.pem ~/ssl-certs/"
    echo "  scp user@192.168.1.10:~/ssl-certs/client-key.pem ~/ssl-certs/"
    exit 1
fi

# Copy certificates to system directory
echo "Copying certificates to system directory..."
cp ca.pem /etc/ssl/certs/
cp client-cert.pem /etc/ssl/certs/
cp client-key.pem /etc/ssl/certs/

# Set permissions
chmod 600 /etc/ssl/certs/*.pem
chmod 644 /etc/ssl/certs/ca.pem

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 9999/udp
ufw --force enable

# Set worker ID
export WORKER_ID="worker-2"

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/worker.service <<EOF
[Unit]
Description=Distributed AI Training System - Worker 2
After=network.target

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/projects/distributed-ai-training
Environment="PATH=/home/user/projects/distributed-ai-training/venv/bin"
Environment="PYTHONUNBUFFERED=1"
Environment="WORKER_ID=worker-2"
ExecStart=/home/user/projects/distributed-ai-training/venv/bin/python src/worker.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user-target
EOF

# Enable and start service
echo "Enabling worker service..."
systemctl daemon-reload
systemctl enable worker.service

echo "=========================================="
echo "Worker 2 setup completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Your IP: 192.168.1.14"
echo "2. Worker ID: worker-2"
echo "3. Worker Type: Medium (will be determined at runtime)"
echo "4. SSL certificates installed in /etc/ssl/certs/"
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
echo "1. Ensure certificates are copied from Head Node (Laptop 1)"
echo "2. Update config.yaml with correct IP addresses"
echo "3. Start Kafka brokers first"
echo "4. Start MongoDB"
echo "5. Then start this worker"
echo "6. Verify worker is consuming messages from Kafka"
