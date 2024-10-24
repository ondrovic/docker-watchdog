FROM docker:latest

# Install necessary packages like bash and jq
RUN apk add --no-cache bash jq

# Copy the watchdog script into the container
COPY watchdog.sh /usr/local/bin/watchdog.sh

# Make the script executable
RUN chmod +x /usr/local/bin/watchdog.sh

# Use bash to run the watchdog script
CMD ["bash", "/usr/local/bin/watchdog.sh"]
