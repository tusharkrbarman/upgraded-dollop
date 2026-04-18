# Deployment Guide

Step-by-step guide to deploy the distributed AI training system on 7 laptops.

## 📋 Prerequisites

### Hardware
- 7 laptops on same local network (192.168.1.0/24)
- Each laptop: 2+ CPU cores, 4GB+ RAM, 20GB+ storage

### Software
- Python 3.11+ (all laptops)
- Java 11+ (Laptops 2, 3)
- MongoDB 7.0 (Laptop 7)
- Ubuntu 22.04 LTS (recommended)

### Network
- All laptops on same LAN
- Static IPs configured or DHCP reservations
- Required ports open: 22, 5000, 9092, 27017, 9999

## 🚀 Deployment Steps

### Step 1: Network Configuration (All Laptops)

#### Configure Static IPs

```bash
# On each laptop, configure static IP
sudo nano /etc/netplan/00-installer-config.yaml

# Add/update network configuration
network:
  ethernets:
    eth0:
      addresses:
        - 192.168.1.XX/24  # Replace XX with laptop number
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
  version: 2

# Apply changes
sudo netplan apply
```

#### Configure Firewall

```bash
# Allow required ports
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 5000/tcp    # API (Laptop 1)
sudo ufw allow 9092/tcp    # Kafka (Laptops 2,3)
sudo ufw allow 27017/tcp   # MongoDB (Laptop 7)
sudo ufw allow 9999/udp    # Heartbeat (Laptops 4,5,6,7)
sudo ufw enable
```

#### Test Connectivity

```bash
# From each laptop, test connectivity
ping 192.168.1.10
ping 192.168.1.11
ping 192.168.1.12
ping 192.168.1.13
ping 192.168.1.14
ping 192.168.1.15
ping 192.168.1.16
```

### Step 2: Generate SSL Certificates (Laptop 1)

```bash
# Create SSL directory
mkdir -p ~/ssl-certs
cd ~/ssl-certs

# Generate CA certificate
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 365 -key ca-key.pem -sha256 -out ca.pem -subj "/CN=DistributedAI-CA"

# Generate server certificates
openssl genrsa -out server-key.pem 4096
openssl req -new -key server-key.pem -out server.csr -subj "/CN=server"
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -days 365

# Generate client certificates
openssl genrsa -out client-key.pem 4096
openssl req -new -key client-key.pem -out client.csr -subj "/CN=client"
openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out client-cert.pem -days 365

# Set permissions
chmod 600 *.pem
```

### Step 3: Distribute Certificates

```bash
# Copy certificates to all laptops
# Use scp, USB drive, or file sharing

# Each laptop needs:
# - ca.pem (CA certificate)
# - client-cert.pem (client certificate)
# - client-key.pem (client private key)

# Laptop 1 also needs:
# - server-cert.pem (server certificate)
# - server-key.pem (server private key)

# Example using scp:
scp ~/ssl-certs/ca.pem user@192.168.1.11:~/ssl-certs/
scp ~/ssl-certs/client-cert.pem user@192.168.1.11:~/ssl-certs/
scp ~/ssl-certs/client-key.pem user@192.168.1.11:~/ssl-certs/
```

### Step 4: Setup MongoDB (Laptop 7)

```bash
# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org

# Start MongoDB without auth
sudo systemctl start mongod

# Create admin user
mongosh admin --eval '
db.createUser({
  user: "admin",
  pwd: "your-password",
  roles: ["root"]
})
'

# Create application user
mongosh dfs_metadata --eval '
db.createUser({
  user: "appuser",
  pwd: "your-password",
  roles: ["readWrite"]
})
'

# Stop MongoDB
sudo systemctl stop mongod

# Enable authentication
sudo nano /etc/mongod.conf
# Add: security.authorization: enabled

# Start MongoDB
sudo systemctl start mongod
```

### Step 5: Setup Kafka Brokers (Laptops 2, 3)

#### Laptop 2 (Broker 1)

```bash
# Install Java
sudo apt update
sudo apt install -y openjdk-11-jdk

# Download Kafka
wget https://downloads.apache.org/kafka/3.6.0/kafka_2.13-3.6.0.tgz
tar -xzf kafka_2.13-3.6.0.tgz
mv kafka_2.13-3.6.0 ~/kafka

# Configure Zookeeper
nano ~/kafka/config/zookeeper.properties
# Add:
dataDir=/tmp/zookeeper
clientPort=2181

# Configure Kafka
nano ~/kafka/config/server.properties
# Add/update:
broker.id=1
listeners=SSL://:9092
advertised.listeners=SSL://192.168.1.11:9092
ssl.keystore.location=/path/to/keystore.jks
ssl.keystore.password=your-password
ssl.key.password=your-password
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=your-password
security.inter.broker.protocol=SSL

# Start Zookeeper
~/kafka/bin/zookeeper-server-start.sh -daemon ~/kafka/config/zookeeper.properties

# Start Kafka
~/kafka/bin/kafka-server-start.sh -daemon ~/kafka/config/server.properties
```

#### Laptop 3 (Broker 2)

```bash
# Same as Laptop 2, but with:
broker.id=2
advertised.listeners=SSL://192.168.1.12:9092
```

### Step 6: Setup Workers (Laptops 4, 5, 6)

```bash
# Install Python
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

# Clone project
git clone <repository-url>
cd distributed-ai-training

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy certificates
sudo mkdir -p /etc/ssl/certs
sudo cp ~/ssl-certs/*.pem /etc/ssl/certs/
sudo chmod 600 /etc/ssl/certs/*.pem

# Update config
nano config_local.yaml
# Update IP addresses and passwords

# Start worker
python src/worker.py
```

### Step 7: Setup Head Node (Laptop 1)

```bash
# Install Python
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

# Clone project
git clone <repository-url>
cd distributed-ai-training

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Copy certificates
sudo mkdir -p /etc/ssl/certs
sudo cp ~/ssl-certs/*.pem /etc/ssl/certs/
sudo chmod 600 /etc/ssl/certs/*.pem

# Update config
nano config_local.yaml
# Update IP addresses and passwords

# Start head node
python src/head_node.py
```

### Step 8: Setup Monitoring (Laptop 7)

```bash
# Already have Python and MongoDB installed

# Start monitoring service
python src/monitoring.py
```

## ✅ Verification

### Test Connectivity

```bash
# From Laptop 1, test all services

# Test Kafka
telnet 192.168.1.11 9092
telnet 192.168.1.12 9092

# Test MongoDB
mongosh "mongodb://appuser:your-password@192.168.1.16:27017/?ssl=true&sslCAFile=/etc/ssl/certs/ca.pem"

# Test API
curl -k https://192.168.1.10:5000/health
```

### Test Security

```bash
# Test SSL
openssl s_client -connect 192.168.1.10:5000 -showcerts

# Test authentication
curl -k -X POST https://192.168.1.10:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}'
```

### Test End-to-End

```bash
# 1. Get JWT token
TOKEN=$(curl -k -X POST https://192.168.1.10:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your-password"}' \
  | jq -r '.token')

# 2. Upload file
curl -k -X POST https://192.168.1.10:5000/api/upload \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"test.jpg","img":"base64data"}'

# 3. List files
curl -k https://192.168.1.10:5000/api/files \
  -H "Authorization: Bearer $TOKEN"

# 4. Check stats
curl -k https://192.168.1.10:5000/api/stats \
  -H "Authorization: Bearer $TOKEN"
```

## 🔧 Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u <service-name> -f

# Check if port is in use
sudo netstat -tulpn | grep <port>
```

### Connection Failed

```bash
# Test network connectivity
ping <ip-address>

# Check firewall
sudo ufw status

# Check service status
sudo systemctl status <service-name>
```

### SSL Errors

```bash
# Verify certificates
openssl x509 -in /etc/ssl/certs/ca.pem -text -noout

# Check certificate paths
ls -la /etc/ssl/certs/
```

## 📋 Deployment Checklist

### Before Deployment
- [ ] 7 laptops available
- [ ] All laptops on same network
- [ ] Static IPs configured
- [ ] Python 3.11+ installed
- [ ] Java 11+ installed (Laptops 2,3)
- [ ] MongoDB installed (Laptop 7)

### Network Setup
- [ ] All laptops can ping each other
- [ ] Firewall configured
- [ ] Required ports open

### Security Setup
- [ ] SSL certificates generated
- [ ] Certificates distributed
- [ ] MongoDB authentication configured
- [ ] Kafka SSL configured

### Service Deployment
- [ ] MongoDB running (Laptop 7)
- [ ] Kafka brokers running (Laptops 2,3)
- [ ] Workers running (Laptops 4,5,6)
- [ ] Head node running (Laptop 1)
- [ ] Monitoring running (Laptop 7)

### Testing
- [ ] Connectivity tests passed
- [ ] Security tests passed
- [ ] End-to-end tests passed

## 🎯 Success Criteria

✅ All 7 laptops communicate
✅ Data flows correctly
✅ Security implemented (SSL/TLS, auth)
✅ Fault tolerance working
✅ Monitoring operational

---

**Estimated Time**: 3-4 hours
**Difficulty**: Medium
**Status**: ✅ Ready for Deployment
