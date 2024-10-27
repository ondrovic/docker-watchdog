#!/bin/bash

echo "Starting watchdog to monitor container health events..."

docker events --filter event=health_status --format "{{json .}}" | while read event; do
  container=$(echo "$event" | jq -r '.Actor.Attributes.name')

  # Get the actual health status using docker inspect
  status=$(docker inspect -f '{{.State.Health.Status}}' "$container")

  echo "$(date) - Container: $container - Status: $status"

  if [ "$status" != "healthy" ]; then
    dependent_containers=()

    # Find dependent containers
    while read dep; do
      labels=$(docker inspect --format '{{ index .Config.Labels "depends_on" }}' "$dep")
      if [[ $labels == *"$container"* ]]; then
        dependent_containers+=("$dep")
      fi
    done < <(docker ps --filter "label=depends_on" --format "{{.Names}}")

    # Restart dependent containers
    for dep in "${dependent_containers[@]}"; do
      echo "$(date) - Restarting dependent container: $dep"
      docker restart "$dep" > /dev/null 2>&1 || echo "$(date) - Failed to restart $dep" >&2
    done
  fi
done
