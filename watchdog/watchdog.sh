#!/bin/bash

echo "Starting watchdog to monitor container health events..."

# Monitor Docker health events
docker events --filter event=health_status --format "{{json .}}" | while read event; do
  container=$(echo "$event" | jq -r '.Actor.Attributes.name')
  status=$(echo "$event" | jq -r '.Actor.Attributes.health_status')

  echo "$(date) - Container: $container - Status: $status"

  # If a container becomes unhealthy, find all dependent containers
  if [ "$status" != "healthy" ]; then
    # Search for containers with 'depends_on' labels containing the unhealthy container name
    dependent_containers=$(docker ps --filter "label=depends_on" --format "{{.Names}}" | while read dep; do
      labels=$(docker inspect --format '{{ index .Config.Labels "depends_on" }}' "$dep")
      # Check if the unhealthy container is in the comma-separated list of dependencies
      if [[ $labels == *"$container"* ]]; then
        echo "$dep"
      fi
    done)

    # Restart all found dependent containers
    for dep in $dependent_containers; do
      echo "$(date) - Restarting dependent container: $dep"
      docker restart "$dep"
    done
  fi