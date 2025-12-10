#!/bin/bash

# Start ollama instances on different ports
OLLAMA_HOST=127.0.0.1:11434 ollama serve &
OLLAMA_HOST=127.0.0.1:11435 ollama serve &
OLLAMA_HOST=127.0.0.1:11436 ollama serve &
OLLAMA_HOST=127.0.0.1:11437 ollama serve &

# Wait for a few seconds to ensure all instances are up
sleep 10

# Pull model on all instances
OLLAMA_HOST=127.0.0.1:11434 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11435 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11436 ollama pull nomic-embed-text &
OLLAMA_HOST=127.0.0.1:11437 ollama pull nomic-embed-text &

# List pulled models on all instances
OLLAMA_HOST=127.0.0.1:11434 ollama list nomic-embed-text:latest
OLLAMA_HOST=127.0.0.1:11435 ollama list nomic-embed-text:latest
OLLAMA_HOST=127.0.0.1:11436 ollama list nomic-embed-text:latest
OLLAMA_HOST=127.0.0.1:11437 ollama list nomic-embed-text:latest

# Use curl to verify each instance is running and load the models on each instance by sending a test request
curl -k -X POST http://localhost:11434/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11434"
  }'

curl -k -X POST http://localhost:11435/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11435"
  }'

(curl -k -X POST http://localhost:11436/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11436"
  }'
)
curl -k -X POST http://localhost:11437/api/embed \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text",
    "input": "test message for instance 11437"
  }'

echo "Started ollama instances on ports 11434, 11435, 11436, and 11437"