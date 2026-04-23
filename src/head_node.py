"""
Head Node Application - Main Coordinator
Handles API requests, coordinates workers, and manages training
Uses FastAPI framework with SSL/TLS and JWT authentication
"""
import os
import sys
import json
import base64
import logging
import time
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from fastapi import FastAPI, HTTPException, UploadFile, File, Depends
from fastapi.responses import JSONResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import jwt
from kafka import KafkaProducer
from pymongo import MongoClient
import pymongo

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import config

# Configure logging
logging.basicConfig(
    level=config.logging_level,
    format=config.logging_format,
    handlers=[
        logging.FileHandler(config.logging_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=config.system_name,
    version=config.system_version,
    description="Distributed AI Training System - Head Node"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=config.api_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Kafka Producer
kafka_producer = None

# Initialize MongoDB Client
mongodb_client = None
mongodb_db = None

# JWT Configuration
JWT_SECRET = config.api_jwt_secret
JWT_ALGORITHM = config.api_jwt_algorithm
JWT_EXPIRATION = config.api_jwt_expiration

# Security
security = HTTPBearer()


# Pydantic models for request/response
class FileUpload(BaseModel):
    name: str
    img: str  # Base64 encoded image


class HealthResponse(BaseModel):
    status: str
    timestamp: str
    system: str
    version: str


class FileResponse(BaseModel):
    status: str
    message: str
    file_id: Optional[str] = None
    topic: Optional[str] = None
    disk_speed: Optional[int] = None


class FilesListResponse(BaseModel):
    status: str
    count: int
    files: List[Dict]


class WorkerResponse(BaseModel):
    status: str
    count: int
    workers: List[Dict]


class StatsResponse(BaseModel):
    status: str
    stats: Dict


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    status: str
    token: str
    expires_in: int


def initialize_kafka():
    """Initialize Kafka producer with SSL"""
    global kafka_producer
    try:
        kafka_producer = KafkaProducer(
            bootstrap_servers=config.kafka_bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            acks='all',
            retries=3,
            security_protocol=config.kafka_security_protocol,
            ssl_cafile=config.kafka_security_ca_file,
            ssl_certfile=config.kafka_security_cert_file,
            ssl_keyfile=config.kafka_security_key_file,
            ssl_password=config.kafka_security_password
        )
        logger.info("Kafka producer initialized successfully with SSL")
    except Exception as e:
        logger.error(f"Failed to initialize Kafka producer: {e}")
        raise


def initialize_mongodb():
    """Initialize MongoDB connection with SSL"""
    global mongodb_client, mongodb_db
    try:
        mongodb_client = MongoClient(
            config.mongodb_uri,
            ssl=config.mongodb_ssl,
            ssl_ca_certs=config.mongodb_ca_file,
            authSource=config.mongodb_auth_source
        )
        mongodb_db = mongodb_client[config.mongodb_database]
        logger.info("MongoDB connection initialized successfully with SSL")
    except Exception as e:
        logger.error(f"Failed to initialize MongoDB: {e}")
        raise


def create_jwt_token(username: str) -> str:
    """Create JWT token for authentication"""
    payload = {
        "sub": username,
        "exp": datetime.utcnow() + timedelta(seconds=JWT_EXPIRATION),
        "iat": datetime.utcnow()
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    return token


def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict:
    """Verify JWT token"""
    try:
        payload = jwt.decode(
            credentials.credentials,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM]
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def get_disk_speed():
    """Measure disk write speed"""
    import tempfile
    test_data = "test" * 1000000  # 4MB test data
    temp_file = os.path.join(tempfile.gettempdir(), 'disk_speed_test.txt')

    try:
        start_time = time.time()
        with open(temp_file, 'w') as f:
            f.write(test_data)
        end_time = time.time()

        file_size = os.path.getsize(temp_file)
        speed = file_size / (end_time - start_time)  # bytes per second

        os.remove(temp_file)
        return int(speed)
    except Exception as e:
        logger.error(f"Failed to measure disk speed: {e}")
        return 0


def determine_worker_topic(disk_speed):
    """Determine which topic to use based on disk speed"""
    if disk_speed >= config.load_balancing_speed_threshold:
        return config.kafka_image_data_fast_topic
    else:
        return config.kafka_image_data_slow_topic


def store_file_metadata(file_data, topic, worker_nodes):
    """Store file metadata in MongoDB"""
    try:
        files_collection = mongodb_db[config.mongodb_collections['files']]

        metadata = {
            'filename': file_data['name'],
            'size': len(base64.b64decode(file_data['img'])),
            'topic': topic,
            'worker_nodes': worker_nodes,
            'created_at': datetime.utcnow(),
            'status': 'distributed'
        }

        result = files_collection.insert_one(metadata)
        logger.info(f"Stored metadata for file {file_data['name']} with ID {result.inserted_id}")
        return result.inserted_id
    except Exception as e:
        logger.error(f"Failed to store file metadata: {e}")
        return None


def get_file_location(filename):
    """Get file location from MongoDB"""
    try:
        files_collection = mongodb_db[config.mongodb_collections['files']]
        file_doc = files_collection.find_one({'filename': filename})
        return file_doc
    except Exception as e:
        logger.error(f"Failed to get file location: {e}")
        return None


def get_all_files():
    """Get all files from MongoDB"""
    try:
        files_collection = mongodb_db[config.mongodb_collections['files']]
        files = list(files_collection.find({}, {'_id': 0}))
        return files
    except Exception as e:
        logger.error(f"Failed to get all files: {e}")
        return []


def get_worker_status():
    """Get status of all workers"""
    try:
        nodes_collection = mongodb_db[config.mongodb_collections['nodes']]
        nodes = list(nodes_collection.find({}, {'_id': 0}))
        return nodes
    except Exception as e:
        logger.error(f"Failed to get worker status: {e}")
        return []


@app.on_event("startup")
async def startup_event():
    """Initialize components on startup"""
    logger.info(f"Starting {config.system_name} v{config.system_version}")
    initialize_kafka()
    initialize_mongodb()
    
    # Verify MongoDB connection
    try:
        mongodb_client.admin.command('ping')
        logger.info("MongoDB connection verified")
    except Exception as e:
        logger.error(f"MongoDB connection verification failed: {e}")
        raise
    
    logger.info("Head node initialized successfully")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("Shutting down head node")
    if kafka_producer:
        kafka_producer.close()
    if mongodb_client:
        mongodb_client.close()


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow().isoformat(),
        system=config.system_name,
        version=config.system_version
    )


@app.post("/api/auth/login", response_model=LoginResponse)
async def login(login_data: LoginRequest):
    """Login endpoint to get JWT token"""
    # In production, verify against database
    # For demo, accept any username/password
    if login_data.username and login_data.password:
        token = create_jwt_token(login_data.username)
        return LoginResponse(
            status="success",
            token=token,
            expires_in=JWT_EXPIRATION
        )
    else:
        raise HTTPException(status_code=401, detail="Invalid credentials")


@app.post("/api/upload", response_model=FileResponse)
async def upload_file(file_data: FileUpload, token: dict = Depends(verify_token)):
    """Upload file endpoint with JWT authentication"""
    try:
        # Determine topic based on disk speed
        disk_speed = get_disk_speed()
        topic = determine_worker_topic(disk_speed)

        logger.info(f"Uploading file {file_data.name} to topic {topic} (disk speed: {disk_speed} bytes/s)")

        # Send to Kafka
        data = {
            'name': file_data.name,
            'img': file_data.img
        }
        future = kafka_producer.send(topic, data)
        kafka_producer.flush()
        future.get(timeout=60)

        # Store metadata
        worker_nodes = ['worker-1', 'worker-2', 'worker-3']  # Simplified for demo
        file_id = store_file_metadata(data, topic, worker_nodes)

        return FileResponse(
            status="success",
            message="File uploaded successfully",
            file_id=str(file_id),
            topic=topic,
            disk_speed=disk_speed
        )

    except Exception as e:
        logger.error(f"Failed to upload file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/files", response_model=FilesListResponse)
async def list_files(token: dict = Depends(verify_token)):
    """List all files endpoint with JWT authentication"""
    try:
        files = get_all_files()
        return FilesListResponse(
            status="success",
            count=len(files),
            files=files
        )
    except Exception as e:
        logger.error(f"Failed to list files: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/files/{filename}")
async def get_file(filename: str, token: dict = Depends(verify_token)):
    """Get file endpoint with JWT authentication"""
    try:
        file_doc = get_file_location(filename)

        if not file_doc:
            raise HTTPException(status_code=404, detail="File not found")

        # Convert ObjectId to string for JSON serialization
        if '_id' in file_doc:
            file_doc['_id'] = str(file_doc['_id'])

        return JSONResponse(
            status_code=200,
            content={
                "status": "success",
                "file": file_doc
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/workers", response_model=WorkerResponse)
async def list_workers(token: dict = Depends(verify_token)):
    """List all workers endpoint with JWT authentication"""
    try:
        workers = get_worker_status()
        return WorkerResponse(
            status="success",
            count=len(workers),
            workers=workers
        )
    except Exception as e:
        logger.error(f"Failed to list workers: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/stats", response_model=StatsResponse)
async def get_stats(token: dict = Depends(verify_token)):
    """Get system statistics endpoint with JWT authentication"""
    try:
        files = get_all_files()
        workers = get_worker_status()

        stats = {
            'total_files': len(files),
            'total_workers': len(workers),
            'system_status': 'healthy',
            'timestamp': datetime.utcnow().isoformat()
        }

        return StatsResponse(
            status="success",
            stats=stats
        )
    except Exception as e:
        logger.error(f"Failed to get stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def main():
    """Main function to start the head node"""
    import uvicorn

    logger.info(f"Starting {config.system_name} v{config.system_version}")
    logger.info(f"API server running on {config.api_host}:{config.api_port}")
    logger.info(f"SSL enabled: {config.api_ssl}")

    uvicorn.run(
        "head_node:app",
        host=config.api_host,
        port=config.api_port,
        ssl_keyfile=config.api_key_file,
        ssl_certfile=config.api_cert_file,
        reload=config.api_debug,
        log_level=config.logging_level.lower()
    )


if __name__ == '__main__':
    main()
