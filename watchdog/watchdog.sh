#!/bin/bash

echo "Starting watchdog to monitor container health events..."

# Monitor Docker health events
docker events --filter event=health_status --format "{{json .}}" | while read event; do
  container=$(echo "$event" | jq -r '.Actor.Attributes.name')
  status=$(echo "$event" | jq -r '.Actor.Attributes.health_status')

  echo "$(date) - Container: $container - Status: $status"

  if [ "$status" != "healthy" ]; then
    dependent_containers=()

    # Collect dependent containers in an array
    while read dep; do
      labels=$(docker inspect --format '{{ index .Config.Labels "depends_on" }}' "$dep")
      if [[ $labels == *"$container"* ]]; then
        dependent_containers+=("$dep")
      fi
    done < <(docker ps --filter "label=depends_on" --format "{{.Names}}")

    # Restart the dependent containers, suppressing output
    for dep in "${dependent_containers[@]}"; do
      echo "$(date) - Restarting dependent container: $dep"
      docker restart "$dep" > /dev/null 2>&1
    done
  fi
done