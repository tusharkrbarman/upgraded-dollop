#!/bin/bash
# Setup script for Kafka Broker 1 (VM-2)

set -e

echo "=========================================="
echo "Setting up Kafka Broker 1 (VM-2)"
echo "=========================================="

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install Java
echo "Installing Java..."
sudo apt install -y openjdk-11-jdk

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> ~/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc
source ~/.bashrc

# Download Kafka
echo "Downloading Kafka..."
cd /tmp
wget https://downloads.apache.org/kafka/3.6.0/kafka_2.13-3.6.0.tgz

# Extract Kafka
echo "Extracting Kafka..."
tar -xzf kafka_2.13-3.6.0.tgz
sudo mv kafka_2.13-3.6.0 /opt/kafka

# Create Kafka data directory
echo "Creating Kafka data directory..."
sudo mkdir -p /var/kafka/data
sudo chown -R student:student /var/kafka

# Configure Kafka
echo "Configuring Kafka..."
sudo tee /opt/kafka/config/server.properties > /dev/null <<EOF
broker.id=1
listeners=PLAINTEXT://192.168.56.11:9092
advertised.listeners=PLAINTEXT://192.168.56.11:9092
log.dirs=/var/kafka/data
num.partitions=3
default.replication.factor=2
min.insync.replicas=1
log.retention.hours=168
zookeeper.connect=192.168.56.11:2181
EOF

# Configure Zookeeper
echo "Configuring Zookeeper..."
sudo mkdir -p /var/zookeeper/data
sudo chown -R student:student /var/zookeeper

echo "1" | sudo tee /var/zookeeper/data/myid > /dev/null

sudo tee /opt/kafka/config/zookeeper.properties > /dev/null <<EOF
tickTime=2000
dataDir=/var/zookeeper/data
clientPort=2181
initLimit=10
syncLimit=5
server.1=192.168.56.11:2888:3888
server.2=192.168.56.12:2888:3888
EOF

# Create systemd service for Zookeeper
echo "Creating Zookeeper service..."
sudo tee /etc/systemd/system/zookeeper.service > /dev/null <<EOF
[Unit]
Description=Apache Zookeeper
After=network.target

[Service]
Type=simple
User=student
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Kafka
echo "Creating Kafka service..."
sudo tee /etc/systemd/system/kafka.service > /dev/null <<EOF
[Unit]
Description=Apache Kafka
After=network.target zookeeper.service

[Service]
Type=simple
User=student
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable services
echo "Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable zookeeper.service
sudo systemctl enable kafka.service

echo "=========================================="
echo "Kafka Broker 1 setup completed successfully!"
echo "=========================================="
echo ""
echo "To start Zookeeper:"
echo "  sudo systemctl start zookeeper"
echo ""
echo "To start Kafka:"
echo "  sudo systemctl start kafka"
echo ""
echo "To check status:"
echo "  sudo systemctl status zookeeper"
echo "  sudo systemctl status kafka"
