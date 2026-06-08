"""
Head Node Application - Main Coordinator
Handles API requests, coordinates workers, and manages training
"""
import os
import sys
import json
import base64
import logging
import time
from binascii import Error as Base64Error
from datetime import datetime, timedelta
from typing import List, Dict, Optional
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.encoders import jsonable_encoder
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
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
    total_chunks: Optional[int] = None
    chunk_size: Optional[int] = None


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


def initialize_kafka():
    """Initialize Kafka producer"""
    global kafka_producer
    try:
        kafka_options = {
            'bootstrap_servers': config.kafka_bootstrap_servers,
            'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
            'acks': 'all',
            'retries': 3,
            'security_protocol': config.kafka_security_protocol
        }
        if config.kafka_security_protocol.upper() == 'SSL':
            kafka_options.update({
                'ssl_cafile': config.kafka_security_ca_file,
                'ssl_certfile': config.kafka_security_cert_file,
                'ssl_keyfile': config.kafka_security_key_file,
                'ssl_password': config.kafka_security_password,
                'ssl_check_hostname': config.security_ssl_check_hostname
            })

        kafka_producer = KafkaProducer(
            **kafka_options
        )
        logger.info(f"Kafka producer initialized successfully using {config.kafka_security_protocol}")
    except Exception as e:
        logger.error(f"Failed to initialize Kafka producer: {e}")
        raise


def initialize_mongodb():
    """Initialize MongoDB connection"""
    global mongodb_client, mongodb_db
    try:
        mongo_options = {'authSource': config.mongodb_auth_source}
        if config.mongodb_ssl:
            mongo_options.update({
                'ssl': True,
                'ssl_ca_certs': config.mongodb_ca_file,
                'tlsAllowInvalidHostnames': not config.security_ssl_check_hostname
            })

        mongodb_client = MongoClient(config.mongodb_uri, **mongo_options)
        mongodb_db = mongodb_client[config.mongodb_database]
        logger.info("MongoDB connection initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize MongoDB: {e}")
        raise


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


def split_into_chunks(data, chunk_size):
    """Split bytes into fixed-size chunks."""
    return [
        data[index:index + chunk_size]
        for index in range(0, len(data), chunk_size)
    ] or [b'']


def store_file_metadata(filename, file_size, topic, worker_nodes, total_chunks):
    """Store file metadata in MongoDB"""
    try:
        files_collection = mongodb_db[config.mongodb_collections['files']]

        metadata = {
            'filename': filename,
            'size': file_size,
            'topic': topic,
            'worker_nodes': worker_nodes,
            'chunk_size': config.storage_chunk_size,
            'total_chunks': total_chunks,
            'chunks': [
                {
                    'index': index,
                    'status': 'queued',
                    'location': None,
                    'processed_at': None
                }
                for index in range(total_chunks)
            ],
            'created_at': datetime.utcnow(),
            'status': 'queued'
        }

        result = files_collection.insert_one(metadata)
        logger.info(f"Stored metadata for file {filename} with ID {result.inserted_id}")
        return result.inserted_id
    except Exception as e:
        logger.error(f"Failed to store file metadata: {e}")
        return None


def mark_file_status(file_id, status):
    """Update file distribution status."""
    try:
        files_collection = mongodb_db[config.mongodb_collections['files']]
        files_collection.update_one(
            {'_id': file_id},
            {'$set': {'status': status, 'updated_at': datetime.utcnow()}}
        )
    except Exception as e:
        logger.error(f"Failed to mark file {file_id} as {status}: {e}")


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


@app.post("/api/upload", response_model=FileResponse)
async def upload_file(file_data: FileUpload):
    """Upload file endpoint"""
    try:
        try:
            file_bytes = base64.b64decode(file_data.img, validate=True)
        except (Base64Error, ValueError) as e:
            raise HTTPException(status_code=400, detail=f"Invalid base64 image data: {e}")

        # Determine topic based on disk speed
        disk_speed = get_disk_speed()
        topic = determine_worker_topic(disk_speed)
        chunks = split_into_chunks(file_bytes, config.storage_chunk_size)
        total_chunks = len(chunks)

        logger.info(
            f"Uploading file {file_data.name} as {total_chunks} chunks to topic {topic} "
            f"(disk speed: {disk_speed} bytes/s)"
        )

        # Store metadata before queueing chunks so workers can update locations.
        worker_nodes = ['worker-1', 'worker-2', 'worker-3']  # Simplified for demo
        file_id = store_file_metadata(
            file_data.name,
            len(file_bytes),
            topic,
            worker_nodes,
            total_chunks
        )
        if file_id is None:
            raise HTTPException(status_code=500, detail="Failed to store file metadata")

        # Send to Kafka
        futures = []
        for chunk_index, chunk in enumerate(chunks):
            chunk_message = {
                'file_id': str(file_id),
                'name': file_data.name,
                'chunk_index': chunk_index,
                'total_chunks': total_chunks,
                'chunk_size': len(chunk),
                'data': base64.b64encode(chunk).decode('utf-8')
            }
            futures.append(kafka_producer.send(topic, chunk_message))

        kafka_producer.flush()
        for future in futures:
            future.get(timeout=60)
        mark_file_status(file_id, 'distributed')

        return FileResponse(
            status="success",
            message="File chunked and queued successfully",
            file_id=str(file_id),
            topic=topic,
            disk_speed=disk_speed,
            total_chunks=total_chunks,
            chunk_size=config.storage_chunk_size
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to upload file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/files", response_model=FilesListResponse)
async def list_files():
    """List all files endpoint"""
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
async def get_file(filename: str):
    """Get file endpoint"""
    try:
        file_doc = get_file_location(filename)

        if not file_doc:
            raise HTTPException(status_code=404, detail="File not found")

        # Convert ObjectId to string for JSON serialization
        if '_id' in file_doc:
            file_doc['_id'] = str(file_doc['_id'])

        return jsonable_encoder({
            "status": "success",
            "file": file_doc
        })
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/workers", response_model=WorkerResponse)
async def list_workers():
    """List all workers endpoint"""
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
async def get_stats():
    """Get system statistics endpoint"""
    try:
        files = get_all_files()
        workers = get_worker_status()
        total_chunks = sum(file_doc.get('total_chunks', 0) for file_doc in files)
        processed_chunks = sum(
            1
            for file_doc in files
            for chunk in file_doc.get('chunks', [])
            if chunk.get('status') == 'processed'
        )
        complete_files = len([
            file_doc for file_doc in files
            if file_doc.get('status') == 'complete'
        ])

        stats = {
            'total_files': len(files),
            'complete_files': complete_files,
            'total_chunks': total_chunks,
            'processed_chunks': processed_chunks,
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
    logger.info(f"API TLS enabled: {config.api_ssl}")

    uvicorn_options = {
        'host': config.api_host,
        'port': config.api_port,
        'reload': config.api_debug,
        'log_level': config.logging_level.lower()
    }
    if config.api_ssl:
        uvicorn_options.update({
            'ssl_keyfile': config.api_key_file,
            'ssl_certfile': config.api_cert_file
        })

    uvicorn.run("head_node:app", **uvicorn_options)


if __name__ == '__main__':
    main()
