"""
Shared Utilities for Distributed AI Training System
Provides common functions used across multiple modules
"""
import os
import time
import logging
from pymongo import MongoClient

from config import config


def setup_logging():
    """
    Setup logging configuration
    Call this at the beginning of each module
    """
    logging.basicConfig(
        level=config.logging_level,
        format=config.logging_format,
        handlers=[
            logging.FileHandler(config.logging_file),
            logging.StreamHandler()
        ]
    )
    return logging.getLogger(__name__)


def get_disk_speed():
    """
    Measure disk write speed
    Returns speed in bytes per second
    """
    test_data = "test" * 1000000  # 4MB test data
    temp_file = "/tmp/disk_speed_test.txt"

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
        logger = logging.getLogger(__name__)
        logger.error(f"Failed to measure disk speed: {e}")
        return 0


def get_mongodb_connection():
    """
    Initialize MongoDB connection
    Returns tuple of (client, database)
    """
    try:
        client = MongoClient(config.mongodb_uri)
        db = client[config.mongodb_database]
        logger = logging.getLogger(__name__)
        logger.info("MongoDB connection initialized successfully")
        return client, db
    except Exception as e:
        logger = logging.getLogger(__name__)
        logger.error(f"Failed to initialize MongoDB: {e}")
        raise
