#!/bin/sh

# Install Docker
sudo apt update
sudo apt install docker.io
sudo systemctl start docker

# Create Docker image
echo "Creating Docker Image"
docker build -t 'virtual_machine' - < Dockerfile
echo "Retrieving Installed Docker Images"
docker images
