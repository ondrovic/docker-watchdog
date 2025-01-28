#!/bin/bash

# Load the .env file from the current directory (/usr/local/bin)
set -a  # Automatically export all variables
source "/usr/local/bin/.env"
set +a  # Stop exporting all variables automatically

VPN_CONTAINER="vpn"                 # Name of the VPN container
DEPENDENT_CONTAINERS=("torrent")    # Add dependent containers here
PORT_VAR="${TORRENT}"               # Port defined in .env as TORRENT

restart_dependent_containers() {
    local parent="$1"
    echo "Parent container '$parent' changed state. Restarting dependent containers..."

    dependent_containers=()

    # Collect dependent containers - only get running containers
    while read -r dep; do
        if [[ -n "$dep" ]]; then  # Check if container name is not empty
            labels=$(docker inspect --format '{{ index .Config.Labels "depends_on" }}' "$dep" 2>/dev/null)
            if [[ $? -eq 0 && -n "$labels" && "$labels" == *"$parent"* ]]; then
                dependent_containers+=("$dep")
            fi
        fi
    done < <(docker ps -f status=running --filter "label=depends_on" --format "{{.Names}}")

    # Only proceed if we found dependent containers
    if [[ ${#dependent_containers[@]} -eq 0 ]]; then
        echo "No running dependent containers found for '$parent'"
        return
    fi

    # Restart dependent containers without printing their names
    for dep in "${dependent_containers[@]}"; do
        if ! docker restart "$dep" > /dev/null 2>&1; then
            echo "Failed to restart dependent container: '$dep'"
        else
            echo "Restarted dependent container: '$dep'"
        fi
    done
}

get_container_id() {
    docker ps --filter "name=$1" -q | head -n 1
}

# Function to check if the VPN container's port is open
docker_port_check() {
    local name="$1" container_id port="$2" command output
    container_id=$(get_container_id "$name")

    # Exit if no container ID found
    if [[ -z "$container_id" ]]; then
        echo "Container '$name' not found or not running"
        return 1
    fi

    # command to check the port
    command="wget -qO- https://portcheck.transmissionbt.com/$port"

    # Execute the command inside the container and capture output
    output=$(docker exec "$container_id" sh -c "$command" 2>/dev/null)

    # Check the output and print open/closed status
    if echo "$output" | grep -q 1; then
        # open
        return 0
    else
        # closed
        return 1
    fi
}

# Function to handle port check and container restart
check_port_and_restart() {
    if ! docker_port_check "$VPN_CONTAINER" "$PORT_VAR"; then
        echo "Port '$PORT_VAR' on container '$VPN_CONTAINER' is closed. Restarting VPN and dependencies."
        if ! docker restart "$VPN_CONTAINER" > /dev/null 2>&1; then
            echo "Failed to restart '$VPN_CONTAINER'"
        else
            restart_dependent_containers "$VPN_CONTAINER"
        fi
    fi
}

# Function to monitor container health events
monitor_container_health() {
    echo "Starting watchdog to monitor container health, restart events and port status..."
    while true; do
        event=$(docker events --filter event=health_status --format "{{json .}}" --until 1m)
        if [[ -n "$event" ]]; then
            container=$(echo "$event" | jq -r '.Actor.Attributes.name')
            if [[ -n "$container" ]]; then  # Check if container name is not empty
                status=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null)

                # Check if the container is the VPN container and if it's down
                if [[ "$container" == "$VPN_CONTAINER" && "$status" != "healthy" ]]; then
                    echo "VPN container '$VPN_CONTAINER' is not healthy, restarting VPN and dependencies."
                    if ! docker restart "$VPN_CONTAINER" > /dev/null 2>&1; then
                        echo "Failed to restart '$VPN_CONTAINER'"
                    else
                        restart_dependent_containers "$VPN_CONTAINER"
                    fi
                fi
            fi
        fi
        sleep 60  # Sleep for 1 minute
    done
}

# Function to run port checks every 15 minutes
run_timed_port_checks() {
    while true; do
        check_port_and_restart
        sleep 900  # Sleep for 15 minutes (900 seconds)
    done
}

# Start monitoring in parallel
monitor_container_health &
run_timed_port_checks &

# Wait for both background processes
wait