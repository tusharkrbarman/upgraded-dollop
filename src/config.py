"""
Configuration Loader for Distributed AI Training System
Supports both local network and internet deployment
"""
import yaml
import os
from pathlib import Path


class Config:
    """Configuration management class"""

    def __init__(self, config_path=None):
        if config_path is None:
            # Default config path - try local network first, then internet
            local_config = os.path.join(
                os.path.dirname(__file__), '..', 'config_local.yaml'
            )
            internet_config = os.path.join(
                os.path.dirname(__file__), '..', 'config_internet.yaml'
            )
            
            # Use local config if exists, otherwise use internet config
            if os.path.exists(local_config):
                config_path = local_config
            elif os.path.exists(internet_config):
                config_path = internet_config
            else:
                # Fallback to default config.yaml
                config_path = os.path.join(
                    os.path.dirname(__file__), '..', 'config.yaml'
                )

        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)

    def get(self, key, default=None):
        """Get configuration value by key"""
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
            else:
                return default
        return value if value is not None else default

    @property
    def system_name(self):
        return self.get('system.name')

    @property
    def system_version(self):
        return self.get('system.version')

    @property
    def kafka_bootstrap_servers(self):
        return self.get('kafka.bootstrap_servers')

    @property
    def kafka_topics(self):
        return self.get('kafka.topics', {})

    @property
    def kafka_image_data_fast_topic(self):
        return self.get('kafka.topics.image_data_fast')

    @property
    def kafka_image_data_slow_topic(self):
        return self.get('kafka.topics.image_data_slow')

    @property
    def kafka_heartbeat_topic(self):
        return self.get('kafka.topics.heartbeat')

    @property
    def kafka_coordination_topic(self):
        return self.get('kafka.topics.coordination')

    @property
    def kafka_consumer_groups(self):
        return self.get('kafka.consumer_groups', {})

    @property
    def kafka_replication_factor(self):
        return self.get('kafka.replication_factor', 2)

    @property
    def kafka_partitions(self):
        return self.get('kafka.partitions', 3)

    @property
    def kafka_security_protocol(self):
        return self.get('kafka.security.protocol', 'SSL')

    @property
    def kafka_security_ca_file(self):
        return self.get('kafka.security.ca_file', '/etc/ssl/certs/ca.pem')

    @property
    def kafka_security_cert_file(self):
        return self.get('kafka.security.cert_file', '/etc/ssl/certs/client-cert.pem')

    @property
    def kafka_security_key_file(self):
        return self.get('kafka.security.key_file', '/etc/ssl/certs/client-key.pem')

    @property
    def kafka_security_password(self):
        return self.get('kafka.security.password', 'your-password')

    @property
    def mongodb_uri(self):
        return self.get('mongodb.uri')

    @property
    def mongodb_database(self):
        return self.get('mongodb.database')

    @property
    def mongodb_collections(self):
        return self.get('mongodb.collections', {})

    @property
    def mongodb_ssl(self):
        return self.get('mongodb.ssl', True)

    @property
    def mongodb_ca_file(self):
        return self.get('mongodb.ca_file', '/etc/ssl/certs/ca.pem')

    @property
    def mongodb_auth_source(self):
        return self.get('mongodb.auth_source', 'admin')

    @property
    def storage_base_path(self):
        return self.get('storage.base_path')

    @property
    def storage_chunk_size(self):
        return self.get('storage.chunk_size', 1048576)

    @property
    def storage_replication_factor(self):
        return self.get('storage.replication_factor', 3)

    @property
    def heartbeat_interval(self):
        return self.get('heartbeat.interval', 1)

    @property
    def heartbeat_timeout(self):
        return self.get('heartbeat.timeout', 3)

    @property
    def heartbeat_port(self):
        return self.get('heartbeat.port', 9999)

    @property
    def heartbeat_max_failures(self):
        return self.get('heartbeat.max_failures', 3)

    @property
    def heartbeat_auth_token(self):
        return self.get('heartbeat.auth_token', 'your-auth-token')

    @property
    def load_balancing_speed_threshold(self):
        return self.get('load_balancing.speed_threshold', 1000000)

    @property
    def load_balancing_weights(self):
        return self.get('load_balancing.scoring_weights', {})

    @property
    def api_host(self):
        return self.get('api.host', '0.0.0.0')

    @property
    def api_port(self):
        return self.get('api.port', 5000)

    @property
    def api_debug(self):
        return self.get('api.debug', False)

    @property
    def api_ssl(self):
        return self.get('api.ssl', True)

    @property
    def api_cert_file(self):
        return self.get('api.cert_file', '/etc/ssl/certs/server-cert.pem')

    @property
    def api_key_file(self):
        return self.get('api.key_file', '/etc/ssl/certs/server-key.pem')

    @property
    def api_cors_origins(self):
        return self.get('api.cors_origins', ['http://localhost:5000', 'http://192.168.1.10:5000'])

    @property
    def api_jwt_secret(self):
        return self.get('api.jwt.secret', 'your-jwt-secret-change-this')

    @property
    def api_jwt_algorithm(self):
        return self.get('api.jwt.algorithm', 'HS256')

    @property
    def api_jwt_expiration(self):
        return self.get('api.jwt.expiration', 7200)

    @property
    def monitoring_enabled(self):
        return self.get('monitoring.enabled', True)

    @property
    def monitoring_log_level(self):
        return self.get('monitoring.log_level', 'INFO')

    @property
    def monitoring_metrics_port(self):
        return self.get('monitoring.metrics_port', 8080)

    @property
    def training_batch_size(self):
        return self.get('training.batch_size', 32)

    @property
    def training_max_epochs(self):
        return self.get('training.max_epochs', 10)

    @property
    def training_learning_rate(self):
        return self.get('training.learning_rate', 0.001)

    @property
    def training_model_type(self):
        return self.get('training.model_type', 'custom')

    @property
    def logging_level(self):
        return self.get('logging.level', 'INFO')

    @property
    def logging_format(self):
        return self.get('logging.format')

    @property
    def logging_file(self):
        return self.get('logging.file')

    @property
    def laptops(self):
        return self.get('laptops', {})


# Global configuration instance
config = Config()
