#!/bin/bash
set -e

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