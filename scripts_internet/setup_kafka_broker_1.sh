#!/bin/bash
# Setup script for Kafka Broker 1 (Laptop 2) - Internet Deployment

set -e

echo "=========================================="
echo "Setting up Kafka Broker 1 (Laptop 2)"
echo "Internet-Based Deployment"
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

# Get domain
read -p "Enter your domain (e.g., kafka1.yourdomain.com): " DOMAIN

# Setup SSL certificates
echo "Setting up SSL certificates..."
read -p "Enter path to CA certificate (from head node): " CA_CERT_PATH

if [ -f "$CA_CERT_PATH" ]; then
    cp "$CA_CERT_PATH" /etc/kafka/ssl/ca.pem
else
    echo "CA certificate not found. Generating self-signed CA..."
    openssl genrsa -out /etc/kafka/ssl/ca-key.pem 4096
    openssl req -new -x509 -days 365 -key /etc/kafka/ssl/ca-key.pem -sha256 -out /etc/kafka/ssl/ca.pem -subj "/CN=KafkaCA"
fi

# Generate server keystore
echo "Generating server keystore..."
keytool -keystore /etc/kafka/ssl/server.keystore.jks -alias localhost -validity 365 -genkey -keyalg RSA -storepass your-password -keypass your-password -dname "CN=$DOMAIN, OU=IT, O=YourOrg, L=City, ST=State, C=US"

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
advertised.listeners=SSL://$DOMAIN:9092
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
echo "1. Your domain: $DOMAIN"
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
echo "1. Configure port forwarding on your router (port 9092)"
echo "2. Share CA certificate (/etc/kafka/ssl/ca.pem) with other laptops"
echo "3. Update config.yaml on other laptops with this broker's address"
echo "4. Test connectivity from head node"
