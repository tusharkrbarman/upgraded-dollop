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
mkdir -p /etc/ssl/certs

# Copy configuration
echo "Setting up configuration..."
cp config_local.yaml config.yaml

# Setup SSL certificates
echo "Setting up SSL certificates..."
mkdir -p ~/ssl-certs
cd ~/ssl-certs

# Generate CA certificate
echo "Generating CA certificate..."
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem -subj "/CN=DistributedAI-CA"

# Generate server certificates
echo "Generating server certificates..."
openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -out server.csr -subj "/CN=server"
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365

# Generate client certificates
echo "Generating client certificates..."
openssl genrsa -out client-key.pem 4096
openssl req -new -key client-key.pem -out client.csr -subj "/CN=client"
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365

# Set permissions
chmod 600 *.pem
chmod 644 ca.pem

# Copy certificates to system directory
echo "Copying certificates to system directory..."
cp ca.pem /etc/ssl/certs/
cp server-cert.pem /etc/ssl/certs/
cp server-key.pem /etc/ssl/certs/
cp client-cert.pem /etc/ssl/certs/
cp client-key.pem /etc/ssl/certs/

# Set system permissions
chmod 600 /etc/ssl/certs/*.pem
chmod 644 /etc/ssl/certs/ca.pem

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
echo "2. SSL certificates installed in /etc/ssl/certs/"
echo "3. CA certificate: /etc/ssl/certs/ca.pem"
echo "4. Firewall configured"
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
echo "API will be available at: https://192.168.1.10:5000"
echo "API Documentation: https://192.168.1.10:5000/docs"
echo ""
echo "NEXT STEPS:"
echo "1. Share CA certificate (/etc/ssl/certs/ca.pem) with other laptops"
echo "2. Share client certificates with other laptops"
echo "3. Update config.yaml on other laptops with this laptop's IP"
echo "4. Test connectivity from other laptops"
echo ""
echo "To share certificates with other laptops:"
echo "  scp /etc/ssl/certs/ca.pem user@192.168.1.11:~/"
echo "  scp /etc/ssl/certs/client-cert.pem user@192.168.1.11:~/"
echo "  scp /etc/ssl/certs/client-key.pem user@192.168.1.11:~/"
echo "  (Repeat for all other laptops)"
