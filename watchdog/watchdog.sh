#!/bin/bash

echo "Starting watchdog to monitor container health and restart events..."

# Function to restart dependent containers
restart_dependent_containers() {
  local parent="$1"
  echo "Parent container $parent changed state. Restarting dependent containers..."

  dependent_containers=()
  
  # Collect dependent containers based on labels
  while read dep; do
    labels=$(docker inspect --format '{{ index .Config.Labels "depends_on" }}' "$dep")
    if [[ $labels == *"$parent"* ]]; then
      dependent_containers+=("$dep")
    fi
  done < <(docker ps --filter "label=depends_on" --format "{{.Names}}")

  # Restart dependent containers
  for dep in "${dependent_containers[@]}"; do
    echo "Restarting dependent container: $dep"
    docker restart "$dep" > /dev/null 2>&1 || echo "$(date +"%m-%d-%Y %I:%M:%S %p") - Failed to restart $dep" >&2
  done
}

# Monitor Docker events for health status and exit events
docker events --filter event=health_status --filter event=die --format "{{json .}}" | while read event; do
  container=$(echo "$event" | jq -r '.Actor.Attributes.name')
  action=$(echo "$event" | jq -r '.Action')
  
  # Get the container's current health status or state
  status=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
  state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)

  echo "Container: $container - Status: $status - State: $state - Action: $action"

  # Restart dependent containers if:
  # - Health status is not healthy
  # - The container state is "exited" (regardless of exit code) or "dead"
  if [ "$status" != "healthy" ] || [[ "$state" == "exited" || "$state" == "dead" ]]; then
    restart_dependent_containers "$container"
  fi
done
