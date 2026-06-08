# Deployment Guide

Step-by-step guide to deploy the distributed AI training system on 6 laptops.

## 📋 Prerequisites

### Hardware
- 6 laptops on same local network (192.168.1.0/24)
- Each laptop: 2+ CPU cores, 4GB+ RAM, 20GB+ storage

### Software
- Python 3.11+ (all laptops)
- Java 11+ (Laptop 2)
- MongoDB 7.0 (Laptop 6)
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
sudo ufw allow 9092/tcp    # Kafka (Laptop 2)
sudo ufw allow 27017/tcp   # MongoDB (Laptop 6)
sudo ufw allow 9999/udp    # Heartbeat (worker laptops and monitoring)
sudo ufw enable
```

#### Test Connectivity

```bash
# From each laptop, test connectivity
ping 192.168.1.10
ping 192.168.1.11
ping 192.168.1.13
ping 192.168.1.14
ping 192.168.1.15
ping 192.168.1.16
```

### Step 2: Setup MongoDB (Laptop 6)

```bash
# Install MongoDB
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org

# Enable authentication
sudo nano /etc/mongod.conf
# Add:
# security.authorization: enabled

# Start MongoDB
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

```

### Step 3: Setup Kafka Broker (Laptop 2)

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
listeners=PLAINTEXT://:9092
advertised.listeners=PLAINTEXT://192.168.1.11:9092

# Start Zookeeper
~/kafka/bin/zookeeper-server-start.sh -daemon ~/kafka/config/zookeeper.properties

# Start Kafka
~/kafka/bin/kafka-server-start.sh -daemon ~/kafka/config/server.properties
```

### Step 4: Setup Workers (Laptops 3, 4, 5)

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

# Update config
nano config_local.yaml
# Update IP addresses and passwords

# Start worker
python src/worker.py
```

### Step 5: Setup Head Node (Laptop 1)

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

# Update config
nano config_local.yaml
# Update IP addresses and passwords

# Start head node
python src/head_node.py
```

### Step 6: Setup Monitoring (Laptop 6)

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

# Test MongoDB
mongosh "mongodb://appuser:your-password@192.168.1.16:27017/dfs_metadata?authSource=dfs_metadata"

# Test API
curl http://192.168.1.10:5000/health
```

### Test End-to-End

```bash
# 1. Upload file
curl -X POST http://192.168.1.10:5000/api/upload \
  -H "Content-Type: application/json" \
  -d '{"name":"test.jpg","img":"base64data"}'

# 2. List files
curl http://192.168.1.10:5000/api/files

# 3. Check stats
curl http://192.168.1.10:5000/api/stats
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

## 📋 Deployment Checklist

### Before Deployment
- [ ] 6 laptops available
- [ ] All laptops on same network
- [ ] Static IPs configured
- [ ] Python 3.11+ installed
- [ ] Java 11+ installed (Laptop 2)
- [ ] MongoDB installed (Laptop 6)

### Network Setup
- [ ] All laptops can ping each other
- [ ] Firewall configured
- [ ] Required ports open

### Security Setup
- [ ] MongoDB authentication configured
- [ ] Kafka broker configured

### Service Deployment
- [ ] MongoDB running (Laptop 6)
- [ ] Kafka broker running (Laptop 2)
- [ ] Workers running (Laptops 3,4,5)
- [ ] Head node running (Laptop 1)
- [ ] Monitoring running (Laptop 6)

### Testing
- [ ] Connectivity tests passed
- [ ] Security tests passed
- [ ] End-to-end tests passed

## 🎯 Success Criteria

✅ All 6 laptops communicate
✅ Data flows correctly
✅ Security implemented for local demo (MongoDB auth)
✅ Fault tolerance working
✅ Monitoring operational

---

**Estimated Time**: 3-4 hours
**Difficulty**: Medium
**Status**: ✅ Ready for Deployment
