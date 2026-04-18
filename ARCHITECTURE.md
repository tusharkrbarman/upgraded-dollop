# System Architecture

Detailed architecture of the distributed AI training system.

## 🌐 System Overview

7 laptops on local network (192.168.1.0/24) distributing ML training data with fault tolerance and security.

## 🏗️ Architecture Diagram

```
                    ┌─────────────────────────┐
                    │   LOCAL NETWORK (LAN)  │
                    │   192.168.1.0/24        │
                    └─────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  Laptop 1    │   │  Laptop 2    │   │  Laptop 3    │
│  Head Node   │   │  Kafka 1     │   │  Kafka 2     │
│  192.168.1.10│   │  192.168.1.11│   │  192.168.1.12│
│  Port: 5000  │   │  Port: 9092  │   │  Port: 9092  │
└───────────────┘   └───────────────┘   └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  Laptop 4    │   │  Laptop 5    │   │  Laptop 6    │
│  Worker 1    │   │  Worker 2    │   │  Worker 3    │
│  192.168.1.13│   │  192.168.1.14│   │  192.168.1.15│
│  Fast        │   │  Medium      │   │  Slow        │
│  Port: 9999  │   │  Port: 9999  │   │  Port: 9999  │
└───────────────┘   └───────────────┘   └───────────────┘
                              │
                              ▼
                    ┌───────────────┐
                    │  Laptop 7    │
                    │  MongoDB +   │
                    │  Monitoring  │
                    │  192.168.1.16│
                    │  Port: 27017 │
                    │  Port: 9999  │
                    └───────────────┘
```

## 📋 Component Details

### 1. Head Node (Laptop 1)

**Purpose**: Coordination and API gateway

**Responsibilities**:
- Receive training requests via REST API
- Distribute data chunks to workers
- Coordinate task execution
- Provide monitoring dashboard

**Technology**:
- FastAPI with SSL/TLS
- JWT authentication
- Kafka producer/consumer
- MongoDB client

**Ports**:
- 5000 (HTTPS API)

### 2. Kafka Brokers (Laptops 2, 3)

**Purpose**: Distributed message broker

**Responsibilities**:
- Reliable message delivery
- Data partitioning
- Fault tolerance
- Load distribution

**Technology**:
- Apache Kafka 3.6.0
- SSL/TLS encryption
- Replication factor: 2
- Partitions: 3

**Topics**:
- `image-data-fast`: Fast worker data
- `image-data-slow`: Slow worker data
- `heartbeat`: Worker health checks

**Ports**:
- 9092 (Kafka SSL)
- 2181 (Zookeeper)

### 3. Workers (Laptops 4, 5, 6)

**Purpose**: Data processing and training

**Responsibilities**:
- Consume data from Kafka
- Process training data
- Send heartbeats
- Report progress

**Technology**:
- Python 3.11
- Kafka consumer
- UDP heartbeat
- ML framework (PyTorch/TensorFlow)

**Types**:
- Worker 1: Fast (high disk I/O)
- Worker 2: Medium
- Worker 3: Slow (low disk I/O)

**Ports**:
- 9999 (UDP heartbeat)

### 4. MongoDB (Laptop 7)

**Purpose**: Metadata storage

**Responsibilities**:
- Store task metadata
- Track worker status
- Maintain system state
- Store authentication data

**Technology**:
- MongoDB 7.0
- SSL/TLS encryption
- Authentication enabled

**Collections**:
- `files`: File metadata
- `nodes`: Worker information
- `replicas`: Data replication info
- `tasks`: Task status

**Ports**:
- 27017 (MongoDB SSL)

### 5. Monitoring (Laptop 7)

**Purpose**: System health monitoring

**Responsibilities**:
- Receive heartbeats
- Detect failures
- Track metrics
- Generate alerts

**Technology**:
- Python 3.11
- UDP listener
- MongoDB client

**Metrics**:
- CPU usage
- Memory usage
- Disk usage
- Network latency

**Ports**:
- 9999 (UDP heartbeat)

## 🔒 Security Architecture

### SSL/TLS Encryption

**Certificate Hierarchy**:
```
CA Certificate (ca.pem)
├── Server Certificate (server-cert.pem)
└── Client Certificate (client-cert.pem)
```

**Encryption Scope**:
- API communication (HTTPS)
- Kafka messaging (SSL)
- MongoDB connections (TLS)

### Authentication

**JWT Authentication**:
- Token-based API authentication
- 1-hour token expiration
- Secret key signing

**MongoDB Authentication**:
- SCRAM-SHA-256
- Role-based access control
- Admin and application users

**Kafka Authentication**:
- SSL certificate-based
- Mutual TLS (mTLS)

### Authorization

**API Endpoints**:
- Public: `/health`, `/api/auth/login`
- Protected: `/api/*` (requires JWT)

**MongoDB Roles**:
- Admin: Full access
- App user: Read/write access

## 📊 Data Flow

### Training Request Flow

```
1. Client → Head Node (HTTPS)
   POST /api/upload
   {name, img_data}

2. Head Node → MongoDB
   Store file metadata

3. Head Node → Kafka
   Publish data chunks
   (partitioned by worker speed)

4. Kafka → Workers
   Consume data chunks
   (based on consumer group)

5. Workers → Processing
   Process training data

6. Workers → Monitoring
   Send heartbeats (UDP)

7. Monitoring → MongoDB
   Update worker status

8. Workers → Head Node
   Report completion

9. Head Node → Client
   Return results
```

### Failure Detection Flow

```
1. Worker stops sending heartbeats
   (timeout: 2 seconds)

2. Monitoring detects failure
   (no heartbeat for 2 seconds)

3. Monitoring → MongoDB
   Update worker status to "failed"

4. Head Node → MongoDB
   Query worker status

5. Head Node → Kafka
   Redistribute failed worker's tasks

6. Other Workers → Kafka
   Consume redistributed tasks
```

## ⚙️ Configuration

### Network Configuration

```yaml
network:
  type: "local"
  subnet: "192.168.1.0/24"
  use_ssl: true
  use_auth: true
```

### Kafka Configuration

```yaml
kafka:
  bootstrap_servers:
    - "192.168.1.11:9092"
    - "192.168.1.12:9092"
  security:
    protocol: "SSL"
    ca_file: "/etc/ssl/certs/ca.pem"
  topics:
    image_data_fast: "image-data-fast"
    image_data_slow: "image-data-slow"
    heartbeat: "heartbeat"
  replication_factor: 2
  partitions: 3
```

### MongoDB Configuration

```yaml
mongodb:
  uri: "mongodb://username:password@192.168.1.16:27017/"
  database: "dfs_metadata"
  ssl: true
  ca_file: "/etc/ssl/certs/ca.pem"
  auth_source: "admin"
```

### API Configuration

```yaml
api:
  host: "0.0.0.0"
  port: 5000
  ssl: true
  cert_file: "/etc/ssl/certs/server-cert.pem"
  key_file: "/etc/ssl/certs/server-key.pem"
  jwt:
    secret: "your-jwt-secret"
    algorithm: "HS256"
    expiration: 3600
```

## 🎯 Design Decisions

### Why 2 Kafka Brokers?

- **High Availability**: If one broker fails, other continues
- **Fault Tolerance**: Replication factor of 2
- **Load Distribution**: Partitions distributed across brokers
- **Data Safety**: No single point of failure

### Why MongoDB as Metadata Node?

- **Flexible Schema**: Easy to evolve data structures
- **Document-Oriented**: Natural fit for metadata
- **Horizontal Scaling**: Can scale if needed
- **High Performance**: Fast read/write operations

### Why UDP for Heartbeats?

- **Low Overhead**: Minimal protocol overhead
- **Fast**: No connection setup
- **Firewall Friendly**: Easier to configure
- **Sufficient**: Heartbeats don't need reliability

### Why SSL/TLS on Local Network?

- **Educational Value**: Demonstrates security best practices
- **Real-World Scenario**: Production systems always use security
- **Data Protection**: Protects training data and metadata
- **Future-Proof**: Ready for internet deployment

## 📈 Performance Characteristics

### Expected Performance

| Metric | Expected | Notes |
|--------|----------|-------|
| Latency | <5ms | Local network |
| Throughput | 800-1000 img/s | Depends on data size |
| Failure Detection | <2s | Heartbeat timeout |
| Recovery Time | <5min | Task redistribution |

### Scalability

- **Horizontal Scaling**: Add more workers
- **Vertical Scaling**: Upgrade worker hardware
- **Network Scaling**: Add more Kafka brokers
- **Storage Scaling**: Add more MongoDB nodes

## 🔍 Monitoring

### Health Metrics

- **Worker Status**: Online/Offline
- **CPU Usage**: Per worker
- **Memory Usage**: Per worker
- **Disk Usage**: Per worker
- **Network Latency**: Between nodes

### Alerting

- **Worker Failure**: Immediate alert
- **High CPU Usage**: Warning at 80%
- **High Memory Usage**: Warning at 80%
- **Disk Space Low**: Warning at 90%

## 🎓 Educational Concepts

### Distributed Systems

- **Message Passing**: Kafka-based communication
- **Coordination**: Head node orchestration
- **Fault Tolerance**: Automatic failure recovery
- **Consistency**: MongoDB as single source of truth

### Security

- **Encryption**: SSL/TLS for all communication
- **Authentication**: JWT and MongoDB auth
- **Authorization**: Role-based access control
- **Certificate Management**: PKI infrastructure

### Microservices

- **Service Decomposition**: Separate services per laptop
- **Service Communication**: Kafka messaging
- **Service Discovery**: Static IP configuration
- **Load Balancing**: Kafka partitioning

---

**Status**: ✅ Architecture Complete
**Complexity**: 🟡 Medium
**Scalability**: 🟢 High
**Security**: 🟢 Production-Ready
