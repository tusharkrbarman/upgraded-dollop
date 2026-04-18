"""
Monitoring Service
Receives heartbeats and monitors system health
Uses UDP socket with authentication
"""
import os
import sys
import json
import logging
import socket
import threading
import time
from datetime import datetime, timedelta
from collections import defaultdict
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
mongodb_client = None
mongodb_db = None
running = False
node_status = defaultdict(dict)
last_heartbeat = defaultdict(datetime)


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


def update_node_status(heartbeat_data):
    """Update node status in memory and MongoDB"""
    try:
        node_id = heartbeat_data['node_id']
        timestamp = datetime.fromtimestamp(heartbeat_data['timestamp'])

        # Verify authentication token
        expected_token = config.heartbeat_auth_token
        if heartbeat_data.get('auth_token') != expected_token:
            logger.warning(f"Invalid heartbeat from {node_id}")
            return

        # Update in-memory status
        node_status[node_id] = heartbeat_data
        last_heartbeat[node_id] = timestamp

        # Update MongoDB
        nodes_collection = mongodb_db[config.mongodb_collections['nodes']]
        nodes_collection.update_one(
            {'node_id': node_id},
            {'$set': {
                'last_heartbeat': timestamp,
                'status': 'active',
                'disk_usage': heartbeat_data.get('disk_usage', 0),
                'cpu_usage': heartbeat_data.get('cpu_usage', 0),
                'memory_usage': heartbeat_data.get('memory_usage', 0)
            }},
            upsert=True
        )

        logger.debug(f"Updated status for node {node_id}")
    except Exception as e:
        logger.error(f"Failed to update node status: {e}")


def check_node_health():
    """Check health of all nodes and mark failures"""
    try:
        current_time = datetime.utcnow()
        timeout_threshold = timedelta(seconds=config.heartbeat_timeout)

        failed_nodes = []

        for node_id, last_time in last_heartbeat.items():
            time_since_heartbeat = current_time - last_time

            if time_since_heartbeat > timeout_threshold:
                # Node is considered failed
                logger.warning(f"Node {node_id} is down (last heartbeat: {time_since_heartbeat.total_seconds():.1f}s ago)")

                # Update MongoDB
                nodes_collection = mongodb_db[config.mongodb_collections['nodes']]
                nodes_collection.update_one(
                    {'node_id': node_id},
                    {'$set': {
                        'status': 'failed',
                        'last_seen': last_time,
                        'failed_at': current_time
                    }}
                )

                failed_nodes.append(node_id)

        if failed_nodes:
            logger.error(f"Failed nodes: {failed_nodes}")
            # Here you could trigger alerts or recovery actions

    except Exception as e:
        logger.error(f"Failed to check node health: {e}")


def heartbeat_server():
    """UDP server to receive heartbeats"""
    global running

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0', config.heartbeat_port))
    sock.settimeout(1.0)  # Non-blocking with timeout

    logger.info(f"Heartbeat server listening on port {config.heartbeat_port}")

    while running:
        try:
            data, addr = sock.recvfrom(1024)
            heartbeat_data = json.loads(data.decode('utf-8'))
            update_node_status(heartbeat_data)
        except socket.timeout:
            continue
        except Exception as e:
            if running:
                logger.error(f"Heartbeat server error: {e}")

    sock.close()
    logger.info("Heartbeat server stopped")


def health_check_thread():
    """Thread for periodic health checks"""
    while running:
        try:
            check_node_health()
            time.sleep(config.heartbeat_interval)
        except Exception as e:
            logger.error(f"Health check thread error: {e}")
            time.sleep(config.heartbeat_interval)


def get_system_status():
    """Get overall system status"""
    try:
        nodes_collection = mongodb_db[config.mongodb_collections['nodes']]
        nodes = list(nodes_collection.find({}, {'_id': 0}))

        active_nodes = [n for n in nodes if n.get('status') == 'active']
        failed_nodes = [n for n in nodes if n.get('status') == 'failed']

        status = {
            'total_nodes': len(nodes),
            'active_nodes': len(active_nodes),
            'failed_nodes': len(failed_nodes),
            'system_health': 'healthy' if len(failed_nodes) == 0 else 'degraded',
            'timestamp': datetime.utcnow().isoformat()
        }

        return status
    except Exception as e:
        logger.error(f"Failed to get system status: {e}")
        return {}


def print_status():
    """Print current system status"""
    try:
        status = get_system_status()
        logger.info(f"System Status: {status}")

        nodes_collection = mongodb_db[config.mongodb_collections['nodes']]
        nodes = list(nodes_collection.find({}, {'_id': 0}))

        logger.info("Node Status:")
        for node in nodes:
            logger.info(f"  {node['node_id']}: {node['status']} (last heartbeat: {node.get('last_heartbeat', 'N/A')})")

    except Exception as e:
        logger.error(f"Failed to print status: {e}")


def main():
    """Main function to start the monitoring service"""
    global running
    running = True

    logger.info("Starting Monitoring Service")

    # Initialize MongoDB
    initialize_mongodb()

    # Start heartbeat server thread
    heartbeat_thread_obj = threading.Thread(target=heartbeat_server, daemon=True)
    heartbeat_thread_obj.start()

    # Start health check thread
    health_check_thread_obj = threading.Thread(target=health_check_thread, daemon=True)
    health_check_thread_obj.start()

    logger.info("Monitoring service started successfully")

    try:
        # Main loop - print status periodically
        while running:
            print_status()
            time.sleep(10)  # Print status every 10 seconds

    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt, shutting down...")
    except Exception as e:
        logger.error(f"Monitoring service error: {e}")
    finally:
        running = False
        logger.info("Monitoring service stopped")


if __name__ == '__main__':
    main()
