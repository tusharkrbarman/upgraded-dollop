"""
Consumer Worker Application
Processes images from Kafka and stores them locally
Uses SSL/TLS for secure communication
"""
import os
import sys
import json
import base64
import logging
import time
import socket
import threading
from datetime import datetime, timedelta
from kafka import KafkaConsumer
from pymongo import MongoClient

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

# Global variables
kafka_consumer = None
mongodb_client = None
mongodb_db = None
worker_id = None
worker_type = None
running = False


def get_write_speed():
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


def determine_worker_type(disk_speed):
    """Determine worker type based on disk speed"""
    if disk_speed >= config.load_balancing_speed_threshold:
        return 'fast'
    else:
        return 'slow'


def determine_topic(worker_type):
    """Determine which topic to subscribe to"""
    if worker_type == 'fast':
        return config.kafka_image_data_fast_topic
    else:
        return config.kafka_image_data_slow_topic


def initialize_kafka(topic):
    """Initialize Kafka consumer with SSL"""
    global kafka_consumer
    try:
        kafka_consumer = KafkaConsumer(
            bootstrap_servers=config.kafka_bootstrap_servers,
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            auto_offset_reset='earliest',
            group_id=f"{worker_type}-workers-group",
            enable_auto_commit=True,
            security_protocol=config.kafka_security_protocol,
            ssl_cafile=config.kafka_security_ca_file,
            ssl_certfile=config.kafka_security_cert_file,
            ssl_keyfile=config.kafka_security_key_file,
            ssl_password=config.kafka_security_password
        )
        kafka_consumer.subscribe([topic])
        logger.info(f"Kafka consumer initialized for topic: {topic} with SSL")
    except Exception as e:
        logger.error(f"Failed to initialize Kafka consumer: {e}")
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


def register_worker():
    """Register worker in MongoDB"""
    try:
        nodes_collection = mongodb_db[config.mongodb_collections['nodes']]

        # Get hostname
        hostname = socket.gethostname()

        worker_info = {
            'node_id': worker_id,
            'hostname': hostname,
            'worker_type': worker_type,
            'disk_speed': get_write_speed(),
            'status': 'active',
            'registered_at': datetime.utcnow(),
            'last_heartbeat': datetime.utcnow()
        }

        # Update or insert worker info
        nodes_collection.update_one(
            {'node_id': worker_id},
            {'$set': worker_info},
            upsert=True
        )

        logger.info(f"Worker {worker_id} registered successfully")
    except Exception as e:
        logger.error(f"Failed to register worker: {e}")


def update_worker_status():
    """Update worker status in MongoDB"""
    try:
        nodes_collection = mongodb_db[config.mongodb_collections['nodes']]

        nodes_collection.update_one(
            {'node_id': worker_id},
            {'$set': {
                'last_heartbeat': datetime.utcnow(),
                'status': 'active'
            }}
        )
    except Exception as e:
        logger.error(f"Failed to update worker status: {e}")


def send_heartbeat():
    """Send heartbeat to monitoring service"""
    try:
        heartbeat_data = {
            'node_id': worker_id,
            'timestamp': int(time.time()),
            'status': 'healthy',
            'disk_usage': get_disk_usage(),
            'cpu_usage': get_cpu_usage(),
            'memory_usage': get_memory_usage(),
            'auth_token': config.heartbeat_auth_token
        }

        # Send via UDP socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.sendto(
            json.dumps(heartbeat_data).encode('utf-8'),
            (config.laptops['mongodb']['ip'], config.heartbeat_port)
        )
        sock.close()

        logger.debug(f"Heartbeat sent for {worker_id}")
    except Exception as e:
        logger.error(f"Failed to send heartbeat: {e}")


def get_disk_usage():
    """Get disk usage percentage"""
    try:
        stat = os.statvfs('/')
        total = stat.f_blocks * stat.f_frsize
        used = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
        return int((used / total) * 100)
    except Exception as e:
        logger.error(f"Failed to get disk usage: {e}")
        return 0


def get_cpu_usage():
    """Get CPU usage percentage"""
    try:
        import psutil
        return int(psutil.cpu_percent())
    except Exception as e:
        logger.error(f"Failed to get CPU usage: {e}")
        return 0


def get_memory_usage():
    """Get memory usage percentage"""
    try:
        import psutil
        return int(psutil.virtual_memory().percent)
    except Exception as e:
        logger.error(f"Failed to get memory usage: {e}")
        return 0


def process_image(file_data):
    """Process and store image locally"""
    try:
        # Create storage directory if it doesn't exist
        storage_dir = os.path.join(config.storage_base_path, worker_id)
        os.makedirs(storage_dir, exist_ok=True)

        # Decode base64 image
        img_data = base64.b64decode(file_data['img'])

        # Save image locally
        file_path = os.path.join(storage_dir, file_data['name'])
        with open(file_path, 'wb') as f:
            f.write(img_data)

        logger.info(f"Processed and saved image: {file_data['name']}")

        # Update MongoDB with file location
        files_collection = mongodb_db[config.mongodb_collections['files']]
        files_collection.update_one(
            {'filename': file_data['name']},
            {'$push': {
                'locations': {
                    'node_id': worker_id,
                    'path': file_path,
                    'processed_at': datetime.utcnow()
                }
            }}
        )

        return True
    except Exception as e:
        logger.error(f"Failed to process image {file_data['name']}: {e}")
        return False


def heartbeat_thread():
    """Thread for sending heartbeats"""
    while running:
        try:
            send_heartbeat()
            update_worker_status()
            time.sleep(config.heartbeat_interval)
        except Exception as e:
            logger.error(f"Heartbeat thread error: {e}")
            time.sleep(config.heartbeat_interval)


def consume_messages():
    """Main consumer loop"""
    global running
    running = True

    logger.info(f"Starting consumer for {worker_id} ({worker_type} worker)")

    # Start heartbeat thread
    heartbeat_thread_obj = threading.Thread(target=heartbeat_thread, daemon=True)
    heartbeat_thread_obj.start()

    try:
        for message in kafka_consumer:
            if not running:
                break

            try:
                file_data = message.value
                logger.info(f"Received message for file: {file_data['name']}")

                # Process the image
                success = process_image(file_data)

                if success:
                    logger.info(f"Successfully processed {file_data['name']}")
                else:
                    logger.error(f"Failed to process {file_data['name']}")

            except Exception as e:
                logger.error(f"Error processing message: {e}")
                continue

    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt, shutting down...")
    except Exception as e:
        logger.error(f"Consumer error: {e}")
    finally:
        running = False
        logger.info(f"Consumer for {worker_id} stopped")


def main():
    """Main function to start the worker"""
    global worker_id, worker_type

    # Get worker ID from environment or use hostname
    worker_id = os.environ.get('WORKER_ID', socket.gethostname())

    logger.info(f"Starting worker: {worker_id}")

    # Measure disk speed and determine worker type
    disk_speed = get_write_speed()
    worker_type = determine_worker_type(disk_speed)

    logger.info(f"Worker type: {worker_type} (disk speed: {disk_speed} bytes/s)")

    # Determine topic
    topic = determine_topic(worker_type)
    logger.info(f"Subscribing to topic: {topic}")

    # Initialize components
    initialize_kafka(topic)
    initialize_mongodb()
    register_worker()

    # Start consuming messages
    consume_messages()


if __name__ == '__main__':
    main()
