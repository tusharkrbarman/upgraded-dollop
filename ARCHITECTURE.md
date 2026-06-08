# System Architecture

Detailed architecture for the local demo version of the Distributed AI Training System.

## System Overview

The local deployment uses 6 laptops on a trusted LAN. It favors reliable setup and easy demonstration over production high availability.

```text
LOCAL NETWORK (LAN) 192.168.1.0/24

Laptop 1  Head Node             192.168.1.10:5000
Laptop 2  Kafka Broker          192.168.1.11:9092
Laptop 3  Worker 1 (Fast)       192.168.1.13
Laptop 4  Worker 2 (Medium)     192.168.1.14
Laptop 5  Worker 3 (Slow)       192.168.1.15
Laptop 6  MongoDB + Monitoring  192.168.1.16:27017,9999
```

## Components

### 1. Head Node

**Purpose:** Coordination and API gateway.

**Responsibilities:**
- Receive file upload requests through FastAPI
- Route uploaded image data to Kafka topics
- Store metadata in MongoDB
- Expose health, file, worker, and stats endpoints

**Ports:**
- `5000` HTTP API

### 2. Kafka Broker

**Purpose:** Message broker for distributing work to workers.

The local demo uses a single Kafka broker to avoid multi-broker cluster setup complexity. Uploaded files are split into chunks before being published to Kafka.

**Configuration:**
- Bootstrap server: `192.168.1.11:9092`
- Security protocol: `PLAINTEXT`
- Replication factor: `1`
- Partitions: `3`
- Upload chunk size: `256 KB`

**Topics:**
- `image-data-fast`
- `image-data-slow`
- `heartbeat`
- `coordination`

### 3. Workers

**Purpose:** Consume image messages, process files, save them locally, and report health.

**Workers:**
- Worker 1: Fast
- Worker 2: Medium
- Worker 3: Slow

Workers determine their topic using measured disk speed.

### 4. MongoDB + Monitoring

**Purpose:** Store metadata and monitor worker health.

**MongoDB stores:**
- File metadata
- Worker node state
- Replica/location metadata

**Monitoring service:**
- Receives UDP heartbeats on port `9999`
- Marks stale workers as failed
- Updates MongoDB with worker metrics

## Security

TLS is disabled for local deployment to keep setup manageable across six laptops. Use this configuration only on a trusted LAN.

Security still includes:
- MongoDB username/password authentication
- A shared heartbeat auth token
- Firewall rules limiting exposed ports

## Data Flow

```text
Client -> Head Node
Head Node -> split file into chunks
Head Node -> Kafka topic, one message per chunk
Worker -> Kafka consume chunk
Worker -> Local chunk storage
Worker -> MongoDB chunk location update
Worker -> Monitoring heartbeat
Monitoring -> MongoDB worker status update
```

## Design Tradeoffs

### Why One Kafka Broker?

- Simpler setup for a college demo
- Fewer Zookeeper/Kafka cluster failure modes
- Easier to verify with `telnet 192.168.1.11 9092`
- Still demonstrates Kafka topics and consumer groups

Tradeoff: Kafka is not highly available in local demo mode. If the Kafka laptop fails, messaging stops.

### Why Disable TLS?

- No certificate generation or distribution
- Fewer Kafka and MongoDB configuration problems
- Appropriate for a trusted classroom/lab LAN

Tradeoff: traffic is not encrypted. Re-enable TLS for internet or untrusted networks.

### Why MongoDB?

- Flexible metadata schema
- Natural JSON-like document model
- Easy tracking of files, workers, and locations

### Why UDP Heartbeats?

- Low overhead
- Simple to implement
- Fast enough for health checks

## Scaling Path

For a more production-like version:
- Reintroduce a proper multi-broker Kafka cluster
- Increase Kafka replication factor
- Move MongoDB to a replica set
- Re-enable TLS for API, Kafka, and MongoDB
- Add API authentication
