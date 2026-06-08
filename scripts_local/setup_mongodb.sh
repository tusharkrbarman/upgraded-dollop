#!/bin/bash
# Setup script for MongoDB + Monitoring (Laptop 7) - Local Network Deployment

set -e

echo "=========================================="
echo "Setting up MongoDB + Monitoring (Laptop 7)"
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

# Install MongoDB
echo "Installing MongoDB..."
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org

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
mkdir -p logs
mkdir -p data

# Copy configuration
echo "Setting up configuration..."
cp config_local.yaml config.yaml

# Configure MongoDB
echo "Configuring MongoDB..."
sudo tee /etc/mongod.conf > /dev/null <<EOF
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
net:
  port: 27017
  bindIp: 0.0.0.0
security:
  authorization: enabled
setParameter:
  authenticationMechanisms: SCRAM-SHA-256
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
EOF

# Create MongoDB data directory
echo "Creating MongoDB data directory..."
sudo mkdir -p /var/lib/mongodb
sudo mkdir -p /var/log/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb
sudo chown -R mongodb:mongodb /var/log/mongodb

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 27017/tcp
ufw allow 9999/udp
ufw --force enable

# Enable and start MongoDB
echo "Enabling MongoDB service..."
sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl start mongod

# Wait for MongoDB to start
echo "Waiting for MongoDB to start..."
sleep 5

# Create database and users
echo "Creating database and users..."
mongosh --eval "
use admin;
db.createUser({
  user: 'admin',
  pwd: 'your-password',
  roles: ['root']
});

use dfs_metadata;
db.createUser({
  user: 'appuser',
  pwd: 'your-password',
  roles: ['readWrite']
});

db.createCollection('files');
db.createCollection('nodes');
db.createCollection('replicas');
db.files.createIndex({filename: 1});
db.nodes.createIndex({node_id: 1});
print('Database and collections created successfully');
"

# Create systemd service for monitoring
echo "Creating monitoring service..."
cat > /etc/systemd/system/monitoring.service <<EOF
[Unit]
Description=Distributed AI Training System - Monitoring Service
After=network.target mongod.service

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/projects/distributed-ai-training
Environment="PATH=/home/user/projects/distributed-ai-training/venv/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=/home/user/projects/distributed-ai-training/venv/bin/python src/monitoring.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable monitoring service
echo "Enabling monitoring service..."
systemctl daemon-reload
systemctl enable monitoring.service

echo "=========================================="
echo "MongoDB + Monitoring setup completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Your IP: 192.168.1.16"
echo "2. MongoDB Port: 27017"
echo "3. Monitoring Port: 9999"
echo "4. TLS disabled for local network deployment"
echo ""
echo "MongoDB Users Created:"
echo "  - admin (root access)"
echo "  - appuser (application access)"
echo "  Password: your-password"
echo ""
echo "To check MongoDB status:"
echo "  sudo systemctl status mongod"
echo ""
echo "To start monitoring:"
echo "  sudo systemctl start monitoring"
echo ""
echo "To check monitoring status:"
echo "  sudo systemctl status monitoring"
echo ""
echo "To view MongoDB logs:"
echo "  sudo tail -f /var/log/mongodb/mongod.log"
echo ""
echo "To view monitoring logs:"
echo "  sudo journalctl -u monitoring -f"
echo ""
echo "To connect to MongoDB:"
echo "  mongosh 'mongodb://appuser:your-password@192.168.1.16:27017/dfs_metadata?authSource=dfs_metadata'"
echo ""
echo "NEXT STEPS:"
echo "1. Update config.yaml on other laptops with this laptop's IP"
echo "2. Start monitoring service"
echo "3. Verify MongoDB is accessible from other laptops"
echo "4. Verify monitoring is receiving heartbeats from workers"
