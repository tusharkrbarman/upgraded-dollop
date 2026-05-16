# Architecture Decision Record (ADR)

This document records all architectural decisions made during the development of the Distributed AI Training System (DSTN).

---

## ADR-001: FastAPI as the API Framework

**Status:** ✅ Accepted

**Context:**
We needed a modern, high-performance web framework for the head node to handle REST API requests, file uploads, and system coordination.

**Decision:**
Use FastAPI instead of Flask or Django.

**Rationale:**
- **Native async support:** Handles concurrent requests efficiently
- **Automatic OpenAPI docs:** `/docs` endpoint provides interactive API documentation
- **Pydantic integration:** Built-in request/response validation
- **Performance:** Faster than Flask due to Starlette ASGI foundation
- **Type hints:** Better developer experience with autocomplete

**Consequences:**
- Team must learn async/await patterns
- Requires ASGI server (uvicorn) instead of WSGI
- Excellent for high-throughput file uploads

---

## ADR-002: Apache Kafka for Message Broker

**Status:** ✅ Accepted

**Context:**
We need to distribute training data chunks from the head node to multiple workers reliably, with fault tolerance.

**Decision:**
Use Apache Kafka instead of RabbitMQ, Redis Streams, or raw sockets.

**Rationale:**
- **Persistence:** Messages are persisted to disk, survive crashes
- **Partitioning:** Built-in data partitioning across multiple brokers
- **Consumer groups:** Automatic load balancing across workers
- **Replay capability:** Can re-read messages if worker fails
- **Throughput:** Optimized for high-volume data streaming
- **Topic-based routing:** Easy to route fast vs slow worker data

**Consequences:**
- Requires Zookeeper (or KRaft in newer versions)
- More complex deployment than Redis
- Significant memory and disk usage
- Needs at least 2 brokers for HA

---

## ADR-003: MongoDB for Metadata Storage

**Status:** ✅ Accepted

**Context:**
We need to store file metadata, worker status, task tracking, and system state persistently.

**Decision:**
Use MongoDB instead of PostgreSQL, SQLite, or etcd.

**Rationale:**
- **Flexible schema:** Metadata structure evolves frequently
- **Document-oriented:** Natural fit for JSON-like metadata
- **Horizontal scaling:** Can add replica sets if needed
- **Performance:** Fast reads/writes for simple queries
- **Python integration:** Excellent pymongo driver

**Consequences:**
- No ACID transactions for complex multi-document operations
- Higher memory usage than SQL alternatives
- Requires separate deployment and monitoring

---

## ADR-004: UDP for Heartbeat Protocol

**Status:** ✅ Accepted

**Context:**
Workers need to send periodic health signals to the monitoring service. Reliability is not critical — if a heartbeat is lost, the next one will arrive.

**Decision:**
Use UDP instead of TCP, HTTP, or Kafka for heartbeats.

**Rationale:**
- **Low overhead:** No connection setup/teardown
- **Fast:** Fire-and-forget semantics
- **Firewall friendly:** Simple port opening
- **Sufficient:** Heartbeats are idempotent; loss of one is acceptable
- **Decoupled:** Monitoring service doesn't need to respond

**Consequences:**
- No delivery guarantee (acceptable for this use case)
- No built-in ordering
- Potential for packet loss during network congestion
- Need custom timeout logic to detect failures

---

## ADR-005: SSL/TLS for All Communication

**Status:** ✅ Accepted

**Context:**
Even though this runs on a local network, we want to demonstrate production security practices.

**Decision:**
Use SSL/TLS encryption for API, Kafka, and MongoDB connections.

**Rationale:**
- **Educational value:** Demonstrates real-world security
- **Data protection:** Prevents eavesdropping on training data
- **Future-proof:** Can extend to internet deployment
- **Assignment requirement:** Shows understanding of security

**Consequences:**
- Certificate management complexity
- Need to distribute CA cert to all nodes
- Slight performance overhead (negligible on LAN)
- Certificate expiration requires rotation

---

## ADR-006: Remove JWT Authentication

**Status:** ✅ Accepted

**Context:**
The original design included JWT token authentication for API endpoints. However, this is a college assignment running on a shared hotspot among teammates in the same room.

**Decision:**
Remove JWT authentication entirely. All API endpoints are now public.

**Rationale:**
- **Threat model:** No external attackers on a shared hotspot
- **Complexity reduction:** Eliminates auth bypass bugs, token management, expiration handling
- **Operational simplicity:** No need to distribute tokens or handle refresh
- **Assignment focus:** Core goal is distributed systems, not security architecture
- **Physical security:** All participants are trusted and co-located

**Consequences:**
- Anyone on the network can access API endpoints
- No user tracking or audit trail
- Must rely on network isolation for security
- If deployed to internet, authentication must be re-added

---

## ADR-007: Static IP Configuration

**Status:** ✅ Accepted

**Context:**
All nodes need to discover each other reliably. We considered DHCP, DNS, service discovery tools (Consul, etcd), and multicast.

**Decision:**
Use static IP addresses configured in YAML files.

**Rationale:**
- **Simplicity:** No additional infrastructure needed
- **Predictability:** IPs never change, easy to debug
- **Assignment scope:** 7 laptops on one hotspot, no dynamic scaling
- **No dependencies:** Doesn't require DHCP server configuration

**Consequences:**
- Manual IP assignment required for each laptop
- Not scalable beyond the planned 7 nodes
- If a laptop's IP changes, config must be updated
- Harder to replace failed nodes dynamically

---

## ADR-008: 7-Node Topology (1 Head + 2 Kafka + 3 Workers + 1 MongoDB)

**Status:** ✅ Accepted

**Context:**
We have exactly 7 laptops available for this assignment. Need to allocate roles optimally.

**Decision:**
- 1 Head Node (FastAPI API + coordination)
- 2 Kafka Brokers (HA message broker)
- 3 Workers (Fast/Medium/Slow for load balancing demo)
- 1 MongoDB + Monitoring (combined to save a laptop)

**Rationale:**
- **Head node separation:** Dedicated API prevents resource contention
- **2 Kafka brokers:** Minimum for HA (survives 1 broker failure)
- **3 workers:** Demonstrates load balancing across different capabilities
- **Combined MongoDB + monitoring:** Fits within 7-laptop constraint

**Consequences:**
- MongoDB and monitoring share resources
- No dedicated monitoring laptop
- If MongoDB laptop fails, monitoring also fails
- Cannot easily add more workers without more hardware

---

## ADR-009: Disk Speed-Based Load Balancing

**Status:** ✅ Accepted

**Context:**
Workers have different disk I/O capabilities. We need to distribute data intelligently.

**Decision:**
Measure disk write speed at runtime and route data to fast vs slow topics.

**Rationale:**
- **Dynamic:** Adapts to actual performance, not just hardware specs
- **Simple:** Single metric (bytes/sec) is easy to measure
- **Effective:** Prevents slow workers from bottlenecking the system
- **Educational:** Clearly demonstrates load balancing concept

**Consequences:**
- Disk speed test adds startup latency
- Measurement is approximate (single test, not sustained)
- Doesn't account for CPU, memory, or network constraints
- Workers are classified into only 2 categories (fast/slow)

---

## ADR-010: Base64 Encoding for Image Transfer

**Status:** ✅ Accepted

**Context:**
Images need to be sent via JSON over HTTP and Kafka. Binary data doesn't fit well in JSON.

**Decision:**
Use Base64 encoding for images in API requests and Kafka messages.

**Rationale:**
- **JSON compatible:** Fits naturally in JSON payloads
- **Simple:** No multipart form handling needed
- **Kafka friendly:** Kafka messages are byte arrays, base64 strings work
- **Universal:** Supported by all languages without libraries

**Consequences:**
- ~33% size increase over raw binary
- Higher memory usage (decode on each end)
- Slower than binary streaming for large files
- No streaming/chunking capability

---

## ADR-011: Python 3.11 as Primary Language

**Status:** ✅ Accepted

**Context:**
All team members are familiar with Python. Need to choose a version.

**Decision:**
Use Python 3.11 across all nodes.

**Rationale:**
- **Team familiarity:** Everyone knows Python
- **Async support:** Native asyncio for concurrent operations
- **Rich ecosystem:** Excellent libraries for Kafka, MongoDB, ML
- **FastAPI compatibility:** Requires Python 3.7+, 3.11 has performance improvements
- **Cross-platform:** Runs on Ubuntu, Windows, macOS

**Consequences:**
- GIL limits true parallelism (use multiprocessing for CPU-bound)
- Slower than C++/Go for high-throughput scenarios
- Large memory footprint compared to Go
- Deployment requires Python environment on each laptop

---

## ADR-012: Separate Config Files per Environment

**Status:** ✅ Accepted

**Context:**
Need to support different network configurations (local lab network vs shared hotspot).

**Decision:**
Maintain separate config files: `config_local.yaml` and `config_internet.yaml`.

**Rationale:**
- **Environment separation:** Different IPs, SSL settings per environment
- **Easy switching:** Code auto-detects which config to load
- **Git safety:** Config files with sensitive data are gitignored
- **Template provided:** Example configs show expected structure

**Consequences:**
- Need to maintain multiple config files
- Risk of configs getting out of sync
- Sensitive data (passwords, IPs) could be accidentally committed
- Deployment requires copying correct config file

---

## ADR-013: Bash Scripts for Deployment

**Status:** ✅ Accepted

**Context:**
Need to set up 7 different laptops with different roles quickly.

**Decision:**
Provide separate bash setup scripts for each role (`setup_head_node.sh`, `setup_worker_1.sh`, etc.).

**Rationale:**
- **One-command setup:** Reduces manual steps and human error
- **Role-specific:** Each script installs only what's needed
- **Reproducible:** Same setup every time
- **Educational:** Scripts document the installation process

**Consequences:**
- Scripts are Ubuntu-specific
- Need to run as root or with sudo
- Hardcoded paths and versions
- No rollback mechanism if setup fails

---

## Summary Table

| ADR | Decision | Status | Impact |
|-----|----------|--------|--------|
| 001 | FastAPI | ✅ Accepted | High |
| 002 | Apache Kafka | ✅ Accepted | High |
| 003 | MongoDB | ✅ Accepted | High |
| 004 | UDP Heartbeats | ✅ Accepted | Medium |
| 005 | SSL/TLS Everywhere | ✅ Accepted | Medium |
| 006 | No JWT Auth | ✅ Accepted | Low |
| 007 | Static IPs | ✅ Accepted | Medium |
| 008 | 7-Node Topology | ✅ Accepted | High |
| 009 | Disk Speed LB | ✅ Accepted | Medium |
| 010 | Base64 Images | ✅ Accepted | Low |
| 011 | Python 3.11 | ✅ Accepted | High |
| 012 | Separate Configs | ✅ Accepted | Low |
| 013 | Bash Scripts | ✅ Accepted | Low |

---

**Last Updated:** May 17, 2026
**Version:** 1.0.0
