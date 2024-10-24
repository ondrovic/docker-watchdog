# Docker Watchdog README

## Overview
This project provides a **Docker watchdog** that monitors container health events and ensures that dependent containers are restarted if their dependencies become unhealthy or restart.

The watchdog script listens for Docker health status events and restarts any dependent containers based on their dependencies.

## Components

### Docker-Autoheal
I use this in conjunction with [willfarrell/docker-autoheal](https://github.com/willfarrell/docker-autoheal) which handles restarting containers when they get into an unhealthy state

### Dockerfile
The Dockerfile builds a watchdog container that:
- Installs `bash` and `jq` for scripting and JSON processing.
- Copies the `watchdog.sh` script into the container.
- Makes the script executable.
- Runs the script using `bash`.

### watchdog.sh
This is the core script responsible for:
1. **Monitoring container health events** using Docker's event system.
2. Identifying dependent containers with `depends_on` labels.
3. **Restarting dependent containers** if any of their dependencies become unhealthy.

## Example Docker Compose Configuration
Here is an example `docker-compose.yml` configuration showcasing a parent service, dependent services, and the watchdog service:

- **Parent service**: A container with a healthcheck.
- **Child services**: Containers dependent on the parent or multiple other containers.
- **Watchdog service**: Monitors health events and manages container restarts.


### Example log entries
```log
Starting watchdog to monitor container health events...

Thu Oct 24 20:04:18 UTC 2024 - Container: watchdog - Status: null
Thu Oct 24 20:05:21 UTC 2024 - Container: parent - Status: null
Thu Oct 24 20:05:21 UTC 2024 - Restarting dependent container: child_one
Thu Oct 24 20:05:40 UTC 2024 - Container: child_one - Status: null
Thu Oct 24 20:05:40 UTC 2024 - Restarting dependent container: child_two
Thu Oct 24 20:05:59 UTC 2024 - Container: child_one - Status: null
Thu Oct 24 20:06:02 UTC 2024 - Container: child_two - Status: null
```

### Example

```yaml
services:
  # parent service
  parent:
    image: example:latest
    container_name: parent
    restart: always
    healthcheck:
      test: ["cmd", "your healthcheck"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"

  # dependent service, single dependency
  child_one:
    image: example:latest
    container_name: child_one
    restart: always
    labels:
      - "depends_on=parent"
    depends_on:
      parent:
        condition: service_healthy
        restart: true
    healthcheck:
      test: ["cmd", "your healthcheck"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"

  # dependent service, multiple dependencies
  child_two:
    image: example:latest
    container_name: child_two
    restart: always
    labels:
      - "depends_on=parent,child_one"
    depends_on:
      parent:
        condition: service_healthy
        restart: true
    healthcheck:
      test: ["cmd", "your healthcheck"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"

  # watchdog to restart dependent containers
  watchdog:
    build: ./watchdog
    container_name: watchdog
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Access to Docker API
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pgrep -f watchdog.sh || exit 1"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"
```

## Usage Instructions

### Step 1: Clone the Repository
First, clone the repository containing the `Dockerfile` and `watchdog.sh`.

```bash
git clone https://github.com/ondrovic/docker-watchdog.git
cd docker-watchdog
```

### Step 2: Build the Watchdog Docker Image
Navigate to the directory containing the `Dockerfile` and build the image.
```bash
docker build -t watchdog .
```

### Step 3: Create a Docker Compose File
Use the following `docker-compose.yml` template to define your services, including the parent and dependent containers, along with the watchdog service.

```yaml
services:
  # parent service
  parent:
    image: example:latest
    container_name: parent
    restart: always
    healthcheck:
      test: ["cmd", "your healthcheck"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"

  # dependent service, single dependency
  child_one:
    image: example:latest
    container_name: child_one
    restart: always
    labels:
      - "depends_on=parent"
    depends_on:
      parent:
        condition: service_healthy
        restart: true
    healthcheck:
      test: ["cmd", "your healthcheck"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"

  # dependent service, multiple dependencies
  child_two:
    image: example:latest
    container_name: child_two
    restart: always
    labels:
      - "depends_on=parent,child_one"
    depends_on:
      parent:
        condition: service_healthy
        restart: true
    healthcheck:
      test: ["cmd", "your healthcheck"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"

  # watchdog to restart dependent containers
  watchdog:
    build: ./watchdog
    container_name: watchdog
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # Access to Docker API
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pgrep -f watchdog.sh || exit 1"]
      interval: "15s"
      retries: 2
      start_period: "20s"
      timeout: "10s"
```