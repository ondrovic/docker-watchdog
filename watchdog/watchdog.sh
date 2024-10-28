#!/bin/bash

echo "Starting watchdog to monitor container health and restart events..."

# Function to find and restart dependent containers
restart_dependent_containers() {
  local parent="$1"
  echo "$(date) - Parent container $parent changed state. Restarting dependent containers..."

  dependent_containers=()
  
  # Collect dependent containers
  while read dep; do
    labels=$(docker inspect --format '{{ index .Config.Labels "depends_on" }}' "$dep")
    if [[ $labels == *"$parent"* ]]; then
      dependent_containers+=("$dep")
    fi
  done < <(docker ps --filter "label=depends_on" --format "{{.Names}}")

  # Restart dependent containers
  for dep in "${dependent_containers[@]}"; do
    echo "$(date) - Restarting dependent container: $dep"
    docker restart "$dep" > /dev/null 2>&1 || echo "$(date) - Failed to restart $dep" >&2
  done
}

# Monitor Docker events for both health status and container restarts
docker events --filter event=health_status --filter event=restart --format "{{json .}}" | while read event; do
  container=$(echo "$event" | jq -r '.Actor.Attributes.name')
  status=$(docker inspect -f '{{.State.Health.Status}}' "$container")

  echo "$(date) - Container: $container - Status: $status"

  # Restart dependent containers if the status is not healthy
  if [ "$status" != "healthy" ]; then
    restart_dependent_containers "$container"
  fi
done
