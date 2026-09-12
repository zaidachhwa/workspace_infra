#!/bin/bash
set -e

# Data lives inside the project volume so it survives container
# stop/start/restart and recreation, same as the rest of the project.
MONGO_DATA_DIR="/home/coder/project/.mongodb-data"
mkdir -p "$MONGO_DATA_DIR"

mongod --dbpath "$MONGO_DATA_DIR" --bind_ip 127.0.0.1 --fork --logpath /tmp/mongod.log

exec /usr/bin/entrypoint.sh --bind-addr 0.0.0.0:8080 .
