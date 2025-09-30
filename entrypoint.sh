#!/bin/bash
set -e

# Some Docker Engines have a different GroupID for the /var/run/docker.sock
# This bit of code will identify the correct group id and apply it to the runner
# So that docker does not encounter an auth error
# Fix Docker socket permissions if needed
# GID_DOCKER can be:
#   - "true" (default): auto-detect Docker socket GID
#   - "false": skip Docker group fix
#   - numeric value: use specific GID
GID_DOCKER="${GID_DOCKER:-true}"

if [ "$GID_DOCKER" != "false" ] && [ -S /var/run/docker.sock ]; then
    if [ "$GID_DOCKER" = "true" ]; then
        # Auto-detect Docker socket GID
        DOCKER_SOCK_GID=$(stat -c "%g" /var/run/docker.sock)
        echo "Auto-detecting Docker socket GID: $DOCKER_SOCK_GID"
    elif [[ "$GID_DOCKER" =~ ^[0-9]+$ ]]; then
        # Use specified numeric GID
        DOCKER_SOCK_GID="$GID_DOCKER"
        echo "Using specified Docker GID: $DOCKER_SOCK_GID"
    else
        echo "Warning: Invalid GID_DOCKER value '$GID_DOCKER'. Should be 'true', 'false', or a number. Skipping Docker group fix."
        DOCKER_SOCK_GID=""
    fi
    
    if [ -n "$DOCKER_SOCK_GID" ]; then
        CURRENT_GID=$(getent group docker | cut -d: -f3)
        if [ "$DOCKER_SOCK_GID" != "$CURRENT_GID" ]; then
            echo "Fixing Docker group ID mismatch: $CURRENT_GID -> $DOCKER_SOCK_GID"
            sudo groupmod -g "$DOCKER_SOCK_GID" docker
            sudo usermod -aG docker runner
        else
            echo "Docker group ID already correct: $CURRENT_GID"
        fi
    fi
elif [ "$GID_DOCKER" = "false" ]; then
    echo "Docker group fix disabled (GID_DOCKER=false)"
fi

# Check Docker socket availability if validation is enabled
# DOCKER_SOCK_ERROR can be "true" (default) to validate or "false" to skip
DOCKER_SOCK_ERROR="${DOCKER_SOCK_ERROR:-true}"

if [ "$DOCKER_SOCK_ERROR" != "false" ]; then
    echo "Validating Docker configuration..."
    
    # Check if Docker socket exists
    if [ ! -S /var/run/docker.sock ]; then
        echo "ERROR: Docker socket not found at /var/run/docker.sock"
        echo "Please ensure you mount the Docker socket with: -v /var/run/docker.sock:/var/run/docker.sock"
        exit 1
    fi
    
    # Test Docker connectivity after potential group fixes
    echo "Testing Docker connectivity..."
fi

# Final Docker validation if enabled
if [ "$DOCKER_SOCK_ERROR" != "false" ]; then
    if ! docker ps >/dev/null 2>&1; then
        echo "ERROR: Docker is not accessible. Common causes:"
        echo "1. Docker socket not mounted: add -v /var/run/docker.sock:/var/run/docker.sock"
        echo "2. Docker daemon not running on host"
        echo "3. Permission issues (try setting GID_DOCKER to your host's Docker group ID)"
        echo ""
        echo "Your host Docker group ID: $(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo 'unknown')"
        echo "Container Docker group ID: $(getent group docker | cut -d: -f3 2>/dev/null || echo 'unknown')"
        echo ""
        echo "To disable this check, set DOCKER_SOCK_ERROR=false"
        exit 1
    fi
    echo "Docker connectivity confirmed ✓"
fi

# Required environment variables
if [ -z "$REPO_URL" ]; then
    echo "Error: REPO_URL environment variable is required"
    exit 1
fi

if [ -z "$RUNNER_TOKEN" ]; then
    echo "Error: RUNNER_TOKEN environment variable is required"
    exit 1
fi

# Optional environment variables with defaults
RUNNER_NAME="${RUNNER_NAME:-docker-runner-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-docker,self-hosted}"
RUNNER_GROUP="${RUNNER_GROUP:-default}"

echo "Configuring GitHub Actions Runner..."
echo "Repository: ${REPO_URL}"
echo "Runner Name: ${RUNNER_NAME}"
echo "Labels: ${RUNNER_LABELS}"

# Remove any existing runner configuration
if [ -f ".runner" ]; then
    echo "Removing existing runner configuration..."
    ./config.sh remove --token "${RUNNER_TOKEN}" || true
fi

# Configure the runner
./config.sh \
    --url "${REPO_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --runnergroup "${RUNNER_GROUP}" \
    --work _work \
    --unattended \
    --replace

# Cleanup function
cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token "${RUNNER_TOKEN}"
}

# Trap signals for graceful shutdown
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

echo "Starting GitHub Actions Runner..."
./run.sh & wait $!