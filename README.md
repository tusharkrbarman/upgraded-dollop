# Distributed AI Training System

A distributed system that enables ML model training on large datasets across multiple devices with limited storage.

## 🎯 Overview

Distributes training data across 6 laptops on a local network based on device capabilities, with fault tolerance and real-time monitoring.

## ✨ Key Features

- **Intelligent Load Balancing**: Distributes data based on disk I/O speed
- **Fault Monitoring**: Detects worker failures with heartbeat checks
- **Demo-Ready Topology**: Single Kafka broker for simpler local setup
- **Real-time Monitoring**: Heartbeat-based health monitoring
- **Security**: MongoDB authentication for the local demo

## 🏗️ System Architecture

### 6 Laptops on Local Network (192.168.1.0/24)

| Laptop | Role | IP Address | Purpose |
|--------|------|------------|---------|
| 1 | Head Node | 192.168.1.10 | Coordination & API |
| 2 | Kafka Broker 1 | 192.168.1.11 | Message broker |
| 3 | Worker 1 (Fast) | 192.168.1.13 | Data processing |
| 4 | Worker 2 (Medium) | 192.168.1.14 | Data processing |
| 5 | Worker 3 (Slow) | 192.168.1.15 | Data processing |
| 6 | MongoDB + Monitoring | 192.168.1.16 | Metadata & monitoring |

### Technology Stack

- **API**: FastAPI
- **Messaging**: Apache Kafka 3.6.0
- **Database**: MongoDB 7.0 with authentication
- **Language**: Python 3.11
- **OS**: Ubuntu 22.04 LTS

## 🚀 Quick Start

### Prerequisites

- 6 laptops on same local network
- Python 3.11+ installed
- Java 11+ (for Kafka)
- MongoDB 7.0 (Laptop 6)

### Deployment Steps

1. **Configure Network**
   ```bash
   # Set static IPs or DHCP reservations
   # Test connectivity: ping 192.168.1.10-16
   ```

2. **Deploy Services** (in order)
   ```bash
   # Laptop 6: MongoDB + Monitoring
   # Laptop 2: Kafka Broker 1
   # Laptop 3: Worker 1
   # Laptop 4: Worker 2
   # Laptop 5: Worker 3
   # Laptop 1: Head Node
   ```

3. **Test System**
   ```bash
   # Test API
   curl http://192.168.1.10:5000/health

   # View API docs
   # Open browser: http://192.168.1.10:5000/docs
   ```

## 📖 Usage

### API Endpoints

```bash
# Health check
GET /health

# Upload file
POST /api/upload
Content-Type: application/json
{"name": "image.jpg", "img": "base64data"}

# Upload response includes chunk metadata
{"file_id": "...", "total_chunks": 4, "chunk_size": 262144}

# List files
GET /api/files

# Get system stats
GET /api/stats
```

### Example Usage

```python
import requests
import base64

# Upload file
with open('image.jpg', 'rb') as f:
    img_data = base64.b64encode(f.read()).decode('utf-8')

response = requests.post('http://192.168.1.10:5000/api/upload',
    json={'name': 'image.jpg', 'img': img_data})

# List files
response = requests.get('http://192.168.1.10:5000/api/files')
```

## 📁 Project Structure

```
distributed-ai-training/
├── config_local.yaml          # Local network config
├── requirements.txt           # Python dependencies
├── README.md                  # This file
├── DEPLOYMENT.md             # Deployment guide
├── ARCHITECTURE.md           # System architecture
├── scripts_local/            # Setup scripts
│   ├── setup_head_node.sh
│   ├── setup_kafka_broker_1.sh
│   ├── setup_worker_1.sh
│   ├── setup_worker_2.sh
│   ├── setup_worker_3.sh
│   └── setup_mongodb.sh
└── src/                      # Source code
    ├── config.py            # Configuration loader
    ├── head_node.py         # Head node (FastAPI)
    ├── worker.py            # Worker application
    └── monitoring.py        # Monitoring service
```

## 🔧 Configuration

Edit `config_local.yaml` to customize:

```yaml
# Network
network:
  subnet: "192.168.1.0/24"
  use_ssl: false
  use_auth: true

# Kafka
kafka:
  bootstrap_servers:
    - "192.168.1.11:9092"
  security:
    protocol: "PLAINTEXT"

# MongoDB
mongodb:
  uri: "mongodb://username:password@192.168.1.16:27017/"
  ssl: false
  auth_source: "dfs_metadata"

# API
  api:
    host: "0.0.0.0"
    port: 5000
    ssl: false
```

## 🎓 Educational Value

Demonstrates:
- **Distributed Systems**: Message passing, coordination, fault tolerance
- **Security**: MongoDB auth
- **Microservices**: Service-oriented architecture
- **Load Balancing**: Intelligent resource allocation
- **Demo Reliability**: Simple topology that is easier to deploy and debug
- **Real-time Monitoring**: Health checks and alerting

## 🔍 Troubleshooting

### Common Issues

**Laptops can't communicate**
- Check all laptops on same network
- Verify IP addresses
- Check firewall settings

**MongoDB connection failed**
- Check MongoDB is running
- Verify authentication enabled
- Check username/password

**Kafka connection failed**
- Verify Kafka broker is running
- Verify broker addresses

## 📚 Documentation

- **DEPLOYMENT.md**: Step-by-step deployment guide
- **ARCHITECTURE.md**: Detailed system architecture

## 📝 License

Educational project for college assignment.

---

**Version**: 2.0.0
**Status**: ✅ Ready for Deployment
**Last Updated**: April 19, 2026
