#!/bin/bash
# Setup script for Head Node (Laptop 1) - Internet Deployment

set -e

echo "=========================================="
echo "Setting up Head Node (Laptop 1)"
echo "Internet-Based Deployment"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Update system
echo "Updating system..."
apt update && apt upgrade -y

# Install Python and pip
echo "Installing Python and pip..."
apt install -y python3 python3-pip python3-venv

# Install system dependencies
echo "Installing system dependencies..."
apt install -y nginx certbot python3-certbot-nginx

# Create project directory
echo "Creating project directory..."
mkdir -p /home/user/projects/distributed-ai-training
cd /home/user/projects/distributed-ai-training

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Create necessary directories
echo "Creating directories..."
mkdir -p storage
mkdir -p logs
mkdir -p data
mkdir -p /etc/ssl/certs

# Copy configuration
echo "Setting up configuration..."
cp config_internet.yaml config.yaml

# Setup SSL certificates
echo "Setting up SSL certificates..."
read -p "Enter your domain (e.g., head-node.yourdomain.com): " DOMAIN

# Option 1: Let's Encrypt
echo "Choose SSL certificate option:"
echo "1. Let's Encrypt (recommended for production)"
echo "2. Self-signed (for testing)"
read -p "Enter choice (1 or 2): " SSL_CHOICE

if [ "$SSL_CHOICE" = "1" ]; then
    echo "Setting up Let's Encrypt certificate..."
    certbot certonly --standalone -d "$DOMAIN"
    
    # Copy certificates to project directory
    cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /etc/ssl/certs/server-cert.pem
    cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /etc/ssl/certs/server-key.pem
    
    # Setup auto-renewal
    echo "0 0 * * * certbot renew --quiet" | crontab -
else
    echo "Generating self-signed certificate..."
    openssl req -x509 -newkey rsa:4096 -keyout /etc/ssl/certs/server-key.pem -out /etc/ssl/certs/server-cert.pem -days 365 -nodes -subj "/CN=$DOMAIN"
fi

# Setup CA certificate for client connections
echo "Setting up CA certificate..."
openssl genrsa -out /etc/ssl/certs/ca-key.pem 4096
openssl req -new -x509 -days 365 -key /etc/ssl/certs/ca-key.pem -sha256 -out /etc/ssl/certs/ca.pem -subj "/CN=MyCA"

# Generate client certificates
echo "Generating client certificates..."
openssl genrsa -out /etc/ssl/certs/client-key.pem 4096
openssl req -new -key /etc/ssl/certs/client-key.pem -out /etc/ssl/certs/client.csr -subj "/CN=client"
openssl x509 -req -in /etc/ssl/certs/client.csr -CA /etc/ssl/certs/ca.pem -CAkey /etc/ssl/certs/ca-key.pem -CAcreateserial -out /etc/ssl/certs/client-cert.pem -days 365

# Set permissions
chmod 600 /etc/ssl/certs/*.pem
chmod 644 /etc/ssl/certs/ca.pem

# Configure Nginx as reverse proxy
echo "Configuring Nginx..."
cat > /etc/nginx/sites-available/distributed-ai-training <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/ssl/certs/server-cert.pem;
    ssl_certificate_key /etc/ssl/certs/server-key.pem;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/distributed-ai-training /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

# Restart Nginx
systemctl restart nginx

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5000/tcp
ufw --force enable

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/head-node.service <<EOF
[Unit]
Description=Distributed AI Training System - Head Node
After=network.target nginx.service

[Service]
Type=simple
User=user
WorkingDirectory=/home/user/projects/distributed-ai-training
Environment="PATH=/home/user/projects/distributed-ai-training/venv/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=/home/user/projects/distributed-ai-training/venv/bin/python src/head_node.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
echo "Enabling head node service..."
systemctl daemon-reload
systemctl enable head-node.service

echo "=========================================="
echo "Head Node setup completed successfully!"
echo "=========================================="
echo ""
echo "IMPORTANT NOTES:"
echo "1. Your domain: $DOMAIN"
echo "2. SSL certificates installed in /etc/ssl/certs/"
echo "3. Nginx configured as reverse proxy"
echo "4. Firewall configured"
echo ""
echo "To start the head node:"
echo "  sudo systemctl start head-node"
echo ""
echo "To check status:"
echo "  sudo systemctl status head-node"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u head-node -f"
echo ""
echo "API will be available at: https://$DOMAIN"
echo "API Documentation: https://$DOMAIN/docs"
echo ""
echo "NEXT STEPS:"
echo "1. Update config.yaml with your actual domain and IPs"
echo "2. Share CA certificate (/etc/ssl/certs/ca.pem) with other laptops"
echo "3. Configure port forwarding on your router (ports 80, 443, 5000)"
echo "4. Test connectivity from other laptops"
