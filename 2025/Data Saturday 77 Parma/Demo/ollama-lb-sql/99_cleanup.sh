#!/bin/bash

# Stop ollama instances
pkill -f "ollama serve"

echo "Stopped ollama instances"

# remove all docker resources, add --volumes if you want to remove volumes too
docker compose down 
