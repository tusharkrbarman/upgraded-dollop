#!/bin/bash
# Setup script for MongoDB (VM-7)

set -e

echo "=========================================="
echo "Setting up MongoDB (VM-7)"
echo "=========================================="

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install MongoDB
echo "Installing MongoDB..."
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org

# Create MongoDB data directory
echo "Creating MongoDB data directory..."
sudo mkdir -p /var/lib/mongodb
sudo mkdir -p /var/log/mongodb
sudo chown -R mongodb:mongodb /var/lib/mongodb
sudo chown -R mongodb:mongodb /var/log/mongodb

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
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
EOF

# Enable and start MongoDB
echo "Enabling MongoDB service..."
sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl start mongod

# Wait for MongoDB to start
echo "Waiting for MongoDB to start..."
sleep 5

# Create database and collections
echo "Creating database and collections..."
mongosh --eval "
use dfs_metadata;
db.createCollection('files');
db.createCollection('nodes');
db.createCollection('replicas');
db.files.createIndex({filename: 1});
db.nodes.createIndex({node_id: 1});
print('Database and collections created successfully');
"

echo "=========================================="
echo "MongoDB setup completed successfully!"
echo "=========================================="
echo ""
echo "To check status:"
echo "  sudo systemctl status mongod"
echo ""
echo "To view logs:"
echo "  sudo tail -f /var/log/mongodb/mongod.log"
echo ""
echo "MongoDB is running on: 192.168.56.16:27017"
