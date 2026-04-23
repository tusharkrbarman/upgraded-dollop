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
chown -R user:user /var/kafka

# Create SSL directory
echo "Creating SSL directory..."
mkdir -p /etc/kafka/ssl
chown -R user:user /etc/kafka

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
cp ca.pem /etc/kafka/ssl/
cp client-cert.pem /etc/kafka/ssl/
cp client-key.pem /etc/kafka/ssl/

# Generate server keystore
echo "Generating server keystore..."
keytool -keystore /etc/kafka/ssl/server.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA -storepass your-password -keypass your-password -dname "CN=192.168.1.11, OU=IT, O=DistributedAI, L=City, ST=State, C=US"

# Generate CSR
keytool -keystore /etc/kafka/ssl/server.keystore.jks -alias localhost -certreq -file /etc/kafka/ssl/server.csr -storepass your-password

# Sign certificate with CA
openssl x509 -req -CA /etc/kafka/ssl/ca.pem -CAkey /etc/kafka/ssl/ca-key.pem -in /etc/kafka/ssl/server.csr -out /etc/kafka/ssl/server-cert-signed -days 365 -CAcreateserial -passin pass:your-password

# Import CA certificate into keystore
keytool -keystore /etc/kafka/ssl/server.keystore.jks -alias CARoot -import -file /etc/kafka/ssl/ca.pem -storepass your-password -noprompt

# Import signed certificate
keytool -keystore /etc/kafka/ssl/server.keystore.jks -alias localhost -import -file /etc/kafka/ssl/server-cert-signed -storepass your-password

# Create truststore
keytool -keystore /etc/kafka/ssl/server.truststore.jks -alias CARoot -import -file /etc/kafka/ssl/ca.pem -storepass your-password -noprompt

# Set permissions
chmod 600 /etc/kafka/ssl/*.jks
chmod 644 /etc/kafka/ssl/*.pem

# Configure Kafka
echo "Configuring Kafka..."
cat > /opt/kafka/config/server.properties <<EOF
broker.id=1
listeners=SSL://:9092
advertised.listeners=SSL://192.168.1.11:9092
log.dirs=/var/kafka/data
num.partitions=3
default.replication.factor=2
min.insync.replicas=1
log.retention.hours=168
zookeeper.connect=localhost:2181

# SSL Configuration
ssl.keystore.location=/etc/kafka/ssl/server.keystore.jks
ssl.keystore.password=your-password
ssl.key.password=your-password
ssl.truststore.location=/etc/kafka/ssl/server.truststore.jks
ssl.truststore.password=your-password
ssl.client.auth=required
security.inter.broker.protocol=SSL
EOF

# Configure Zookeeper
echo "Configuring Zookeeper..."
mkdir -p /var/zookeeper/data
chown -R user:user /var/zookeeper

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
User=user
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
User=user
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
echo "2. SSL certificates configured in /etc/kafka/ssl/"
echo "3. Keystore password: your-password"
echo "4. Truststore password: your-password"
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
echo "1. Ensure certificates are copied from Head Node (Laptop 1)"
echo "2. Start Zookeeper first, then Kafka"
echo "3. Test connectivity from Head Node"
echo "4. Verify Kafka is accessible from other laptops"
