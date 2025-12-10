#!/bin/bash

# Start nginx and SQL Server
docker compose up --build -d

echo "Started nginx load balancer, and SQL Server 2025"

# Use curl to verify the nginx load balancer is working by sending a test request to port 443
curl -k -X POST https://localhost:443/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 443"
  }'

# Use curl to verify the nginx single backend is working by sending a test request to port 444
curl -k -X POST https://localhost:444/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 444"
  }'
   