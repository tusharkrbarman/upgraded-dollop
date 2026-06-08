#!/bin/bash
# Setup script for Kafka Broker 1 (Laptop 2) - Local Network Deployment

set -e

echo "=========================================="
echo "Setting up Kafka Broker 1 (Laptop 2)"
echo "Local Network Deployment"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

SERVICE_USER="${SUDO_USER:-user}"

# Update system
echo "Updating system..."
apt update && apt upgrade -y

# Install Java
echo "Installing Java..."
apt install -y openjdk-11-jdk

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64' >> /etc/environment
source /etc/environment

# Download Kafka
echo "Downloading Kafka..."
cd /tmp
wget https://downloads.apache.org/kafka/3.6.0/kafka_2.13-3.6.0.tgz

# Extract Kafka
echo "Extracting Kafka..."
tar -xzf kafka_2.13-3.6.0.tgz
mv kafka_2.13-3.6.0 /opt/kafka

# Create Kafka data directory
echo "Creating Kafka data directory..."
mkdir -p /var/kafka/data
chown -R "$SERVICE_USER:$SERVICE_USER" /var/kafka

# Configure Kafka
echo "Configuring Kafka..."
cat > /opt/kafka/config/server.properties <<EOF
broker.id=1
listeners=PLAINTEXT://:9092
advertised.listeners=PLAINTEXT://192.168.1.11:9092
log.dirs=/var/kafka/data
num.partitions=3
default.replication.factor=1
min.insync.replicas=1
log.retention.hours=168
zookeeper.connect=localhost:2181
EOF

# Configure Zookeeper
echo "Configuring Zookeeper..."
mkdir -p /var/zookeeper/data
chown -R "$SERVICE_USER:$SERVICE_USER" /var/zookeeper

echo "1" > /var/zookeeper/data/myid

cat > /opt/kafka/config/zookeeper.properties <<EOF
tickTime=2000
dataDir=/var/zookeeper/data
clientPort=2181
initLimit=10
syncLimit=5
maxClientCnxns=0
admin.enableServer=false
EOF

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 9092/tcp
ufw allow 2181/tcp
ufw --force enable

# Create systemd service for Zookeeper
echo "Creating Zookeeper service..."
cat > /etc/systemd/system/zookeeper.service <<EOF
[Unit]
Description=Apache Zookeeper
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Kafka
echo "Creating Kafka service..."
cat > /etc/systemd/system/kafka.service <<EOF
[Unit]
Description=Apache Kafka
After=network.target zookeeper.service

[Service]
Type=simple
User=$SERVICE_USER
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable services
echo "Enabling services..."
systemctl daemon-reload
systemctl enable zookeeper.service
systemctl enable kafka.service

echo "=========================================="
echo "Kafka Broker 1 setup completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Your IP: 192.168.1.11"
echo "2. Kafka listener: PLAINTEXT://192.168.1.11:9092"
echo "3. TLS disabled for local network deployment"
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
echo ""
echo "To view logs:"
echo "  sudo journalctl -u zookeeper -f"
echo "  sudo journalctl -u kafka -f"
echo ""
echo "NEXT STEPS:"
echo "1. Start Zookeeper first, then Kafka"
echo "2. Test connectivity from Head Node"
echo "3. Verify Kafka is accessible from other laptops"
