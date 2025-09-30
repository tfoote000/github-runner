# Custom GitHub Actions Runner Docker

A production-ready, self-hosted GitHub Actions runner that runs in Docker. This provides full control over the runner environment and makes it easy to scale and manage your CI/CD infrastructure.

## ⚠️ SECURITY WARNING

**This container requires access to the Docker daemon (`/var/run/docker.sock`) which grants significant privileges:**

- **Full Docker Control**: Can create, modify, and delete any container on the host
- **Container Escape**: Can mount host filesystem and escape container isolation
- **Host System Access**: Can potentially access sensitive host files and processes
- **Network Access**: Can access internal Docker networks and other containers

**Security Implications:**
- The runner container effectively has root-equivalent access to the host system
- Malicious or compromised workflows could exploit this access
- Other containers on the same host may be accessible to the runner

**Use at your own risk.** Only deploy this runner in trusted environments and ensure:
- Repository access is limited to trusted users
- Workflow files are reviewed before execution
- The host system contains no sensitive data that shouldn't be accessible
- Consider network isolation and other hardening measures for production use

For enhanced security options, see the [Security Considerations](#security-considerations) section below.

---

## Features

- 🚀 **Clean Ubuntu 22.04 base** - Stable and widely compatible
- 🐳 **Docker-in-Docker support** - Build and run containers within your workflows
- 🔒 **Security-first design** - Runs as non-root user with controlled sudo access
- ♻️ **Graceful lifecycle management** - Properly registers/deregisters with GitHub
- 🎯 **Auto-replace functionality** - Seamlessly replaces existing runners
- ⚙️ **Fully customizable** - Easy configuration via environment variables
- 💾 **Persistent work directory** - Maintains build artifacts between restarts
- 📊 **Resource limits** - Built-in CPU and memory constraints

## Prerequisites

- Docker and Docker Compose installed on your host machine
- A GitHub repository where you want to add the runner
- GitHub Personal Access Token or runner registration token

## Available Images

This project automatically builds and publishes Docker images to GitHub Container Registry (GHCR):

- **Latest stable**: `ghcr.io/tfoote000/github-runner:latest`
- **Branch builds**: `ghcr.io/tfoote000/github-runner:master`
- **Tagged releases**: `ghcr.io/tfoote000/github-runner:v1.0.0`

All images are built for multiple architectures:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM64/Apple Silicon)

## Quick Start

### 1. Clone or create the project structure

```bash
mkdir github-runner && cd github-runner
```

### 2. Create the necessary files

The project includes:
- `Dockerfile` - Builds the runner image
- `entrypoint.sh` - Handles runner registration and lifecycle
- `docker-compose.yml` - Orchestrates the container
- `.env.example` - Template for environment variables

### 3. Configure your runner

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and add your runner token:

```bash
# Get this token from GitHub: Settings -> Actions -> Runners -> New self-hosted runner
RUNNER_TOKEN=YOUR_ACTUAL_TOKEN_HERE
```

### 4. Update docker-compose.yml

Edit `docker-compose.yml` and set your repository URL:

```yaml
environment:
  - REPO_URL=https://github.com/YOUR_USERNAME/YOUR_REPO
```

### 5. Build and run

#### Option A: Use Pre-built Image from GitHub Container Registry (Recommended)

The easiest way to get started is using the pre-built image:

```bash
# Pull the latest image
docker pull ghcr.io/tfoote000/github-runner:latest

# Start the runner in detached mode
docker-compose up -d

# View logs
docker-compose logs -f
```

#### Option B: Build Locally

If you want to customize the Dockerfile or build locally:

```bash
# Build the runner image
docker-compose build

# Start the runner in detached mode
docker-compose up -d

# View logs
docker-compose logs -f
```

## Configuration Options

### Environment Variables

All environment variables can be configured in the `docker-compose.yml` file. The `.env` file is used primarily for sensitive values like `RUNNER_TOKEN`.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `REPO_URL` | **Yes** | - | GitHub repository URL |
| `RUNNER_TOKEN` | **Yes** | - | Registration token from GitHub |
| `RUNNER_NAME` | No | `docker-runner-$(hostname)` | Name displayed in GitHub |
| `RUNNER_LABELS` | No | `docker,self-hosted` | Comma-separated labels |
| `RUNNER_GROUP` | No | `default` | Runner group assignment |
| `GID_DOCKER` | No | `true` | Docker group handling: `true` (auto-detect), `false` (disabled), or numeric GID |
| `DOCKER_SOCK_ERROR` | No | `true` | Docker validation: `true` (validate Docker access), `false` (skip validation) |

#### REPO_URL (Required)

The full URL of the GitHub repository or organization where the runner will be registered.

**Examples:**
- Repository-level runner: `https://github.com/username/repository`
- Organization-level runner: `https://github.com/organization`

**Configuration:** Set this directly in `docker-compose.yml` under `environment` section.

```yaml
environment:
  - REPO_URL=https://github.com/YOUR_USERNAME/YOUR_REPO
```

**Important:** The URL must match exactly where you generated the runner token. Organization runners require organization-level tokens.

#### RUNNER_TOKEN (Required)

The registration token from GitHub that authorizes the runner to register with your repository or organization.

**Important Security Notes:**
- Tokens expire after **1 hour** from generation
- Generate the token immediately before starting the runner
- **Never commit tokens to version control**
- Store in `.env` file (which should be in `.gitignore`)

**Where to get it:**

1. **Repository-level:** Settings → Actions → Runners → New self-hosted runner
2. **Organization-level:** Organization Settings → Actions → Runners → New runner
3. **Via API:** Use the GitHub API to programmatically generate tokens (see [Getting Your Runner Token](#getting-your-runner-token))

**Configuration:** Store in `.env` file:

```bash
RUNNER_TOKEN=your_actual_token_here
```

Then reference in `docker-compose.yml`:

```yaml
environment:
  - RUNNER_TOKEN=${RUNNER_TOKEN}
```

#### RUNNER_NAME (Optional)

The name that will be displayed in GitHub's runner list. This helps identify runners when managing multiple instances.

**Default:** `docker-runner-$(hostname)` (automatically includes the container's hostname)

**Examples:**
- `docker-runner-01`, `docker-runner-02` for numbered runners
- `production-runner`, `staging-runner` for environment-specific runners
- `build-server-01`, `deploy-agent-02` for purpose-specific runners

**Configuration:**

```yaml
environment:
  - RUNNER_NAME=docker-runner-01
```

**Best Practices:**
- Use descriptive names that indicate the runner's purpose or environment
- Include numbers when running multiple instances
- Avoid special characters that might cause issues in scripts

#### RUNNER_LABELS (Optional)

Comma-separated list of labels to assign to the runner. Labels are used in GitHub Actions workflow files to target specific runners with the `runs-on` directive.

**Default:** `docker,self-hosted`

**Examples:**
- `docker,self-hosted,linux` - Basic labels for a Linux runner with Docker
- `docker,self-hosted,linux,x64,production` - Include architecture and environment
- `docker,gpu,cuda,ml` - For specialized ML/AI workloads
- `docker,build,deploy,nodejs` - For specific capabilities

**Configuration:**

```yaml
environment:
  - RUNNER_LABELS=docker,self-hosted,linux,x64
```

**Using in Workflows:**

```yaml
jobs:
  build:
    runs-on: [self-hosted, docker, linux]
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: make build
```

**Best Practices:**
- Always include `self-hosted` to distinguish from GitHub-hosted runners
- Add labels for OS, architecture, installed tools, and environment
- Use consistent label naming across all runners
- Document custom labels for your team

#### RUNNER_GROUP (Optional)

The runner group to assign this runner to. Runner groups are an Enterprise/Organization feature that allows you to control which repositories can access specific runners.

**Default:** `default`

**Examples:**
- `default` - Available to all repositories (default group)
- `production` - Only for production deployments
- `development` - For development and testing
- `staging` - For staging environment
- `security-scanned` - For runners with enhanced security

**Configuration:**

```yaml
environment:
  - RUNNER_GROUP=production
```

**Important Notes:**
- Runner groups must be created in GitHub before assigning runners to them
- This is primarily an Enterprise/Organization feature
- Repository-level runners typically use the `default` group
- Group access is controlled in GitHub Settings → Actions → Runner groups

**Best Practices:**
- Use groups to isolate runners by security level or environment
- Assign groups based on repository access requirements
- Document which repositories have access to each group

#### GID_DOCKER (Optional)

Controls how the container handles Docker socket permissions when mounting `/var/run/docker.sock` from the host.

**Default:** `true` (auto-detect)

**Options:**
- `true` - Automatically detects the Docker socket's group ID and adjusts the container's docker group to match
- `false` - Disables Docker group fixing (useful if handling permissions externally)
- Numeric value (e.g., `988`) - Sets the docker group to a specific GID

**Configuration:**

```yaml
environment:
  # Auto-detect (default behavior)
  - GID_DOCKER=true
  
  # Disable Docker group fixing
  - GID_DOCKER=false
  
  # Use specific Docker group ID
  - GID_DOCKER=988
```

**When to use each option:**

- **`true` (recommended)**: Best for most scenarios. Automatically handles different host configurations
- **`false`**: When using rootless Docker, alternative permission setups, or when the container runs as root
- **Numeric value**: When you know your host's Docker group ID and want to avoid auto-detection

**Common Docker group IDs by distribution:**
- Ubuntu/Debian: typically `999` or `998`
- CentOS/RHEL: typically `992` or `990`
- Docker Desktop: varies by platform

**Troubleshooting Docker permissions:**

If you see "permission denied" errors when accessing Docker:

1. Check your host's Docker group ID: `getent group docker | cut -d: -f3`
2. Set `GID_DOCKER` to that specific value
3. Or use `GID_DOCKER=true` for automatic detection

This feature solves the common issue where mounting Docker socket results in permission denied errors due to group ID mismatches between host and container.

#### DOCKER_SOCK_ERROR (Optional)

Controls whether the container validates Docker socket access during startup.

**Default:** `true` (validate Docker access)

**Options:**
- `true` - Validates that Docker socket is mounted and accessible, exits with error if not
- `false` - Skips Docker validation (useful for containers that don't need Docker)

**Configuration:**

```yaml
environment:
  # Validate Docker access (default)
  - DOCKER_SOCK_ERROR=true
  
  # Skip Docker validation
  - DOCKER_SOCK_ERROR=false
```

**When to use each option:**

- **`true` (recommended)**: Ensures Docker is properly configured before starting the runner
- **`false`**: When running containers that don't need Docker access, or when using alternative Docker setups

**What it validates:**

1. Docker socket exists at `/var/run/docker.sock`
2. Docker daemon is accessible (runs `docker ps` test)
3. Provides helpful error messages with troubleshooting tips

**Error examples:**

If validation fails, you'll see helpful messages like:
```
ERROR: Docker socket not found at /var/run/docker.sock
Please ensure you mount the Docker socket with: -v /var/run/docker.sock:/var/run/docker.sock
```

Or:
```
ERROR: Docker is not accessible. Common causes:
1. Docker socket not mounted: add -v /var/run/docker.sock:/var/run/docker.sock
2. Docker daemon not running on host
3. Permission issues (try setting GID_DOCKER to your host's Docker group ID)
```

This feature helps catch Docker configuration issues early and provides clear guidance for fixing them.

### Resource Limits

The docker-compose.yml includes configurable resource limits:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'      # Maximum CPU cores
      memory: 4G     # Maximum memory
    reservations:
      cpus: '1'      # Reserved CPU cores
      memory: 2G     # Reserved memory
```

## Getting Your Runner Token

### Option 1: Repository-level runner

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Actions** → **Runners**
3. Click **New self-hosted runner**
4. Copy the token from the configuration instructions

### Option 2: Organization-level runner

1. Navigate to your organization settings
2. Go to **Actions** → **Runners**
3. Click **New runner**
4. Copy the token from the configuration instructions

### Option 3: Using GitHub API

```bash
# For repository runners
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/OWNER/REPO/actions/runners/registration-token

# For organization runners
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/orgs/ORG/actions/runners/registration-token
```

## Usage in GitHub Actions

Once your runner is running, you can use it in your workflows:

```yaml
name: Build with Self-Hosted Runner

on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, docker, linux]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Run build
        run: |
          echo "Running on self-hosted runner"
          docker --version
```

## Managing Multiple Runners

To run multiple runners, you can either:

### Option 1: Multiple containers in docker-compose

```yaml
services:
  github-runner-1:
    build: .
    container_name: github-runner-1
    environment:
      - RUNNER_NAME=docker-runner-01
    # ... other settings

  github-runner-2:
    build: .
    container_name: github-runner-2
    environment:
      - RUNNER_NAME=docker-runner-02
    # ... other settings
```

### Option 2: Scale with docker-compose

```bash
docker-compose up -d --scale github-runner=3
```

## Customizing the Runner Image

### Adding Additional Tools

Edit the Dockerfile to include any tools your workflows need:

```dockerfile
# Add Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && \
    apt-get install -y nodejs

# Add Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv

# Add AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip
```

### Adding GitHub CLI

```dockerfile
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt update && \
    apt install gh -y
```

## Monitoring and Maintenance

### View Runner Status

```bash
# Check if runner is running
docker-compose ps

# View real-time logs
docker-compose logs -f

# View last 100 lines of logs
docker-compose logs --tail=100
```

### Restart Runner

```bash
# Graceful restart
docker-compose restart

# Force recreate
docker-compose up -d --force-recreate
```

### Update Runner Version

The Dockerfile automatically downloads the latest runner version. To update:

```bash
# Rebuild the image
docker-compose build --no-cache

# Restart with new image
docker-compose up -d
```

## Troubleshooting

### Runner Not Appearing in GitHub

1. Check the logs for registration errors:
   ```bash
   docker-compose logs | grep -i error
   ```

2. Verify your token is valid and hasn't expired

3. Ensure the REPO_URL is correct

### Permission Denied Errors

If you see Docker permission errors:

```bash
# Ensure docker.sock has correct permissions
sudo chmod 666 /var/run/docker.sock

# Or add your user to docker group
sudo usermod -aG docker $USER
```

### Runner Can't Execute Docker Commands

Ensure the Docker socket is properly mounted in docker-compose.yml:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

### Cleanup Stale Runners

To remove offline runners from GitHub:

1. Go to Settings → Actions → Runners
2. Click on the offline runner
3. Click "Remove"

## Security Considerations

### Docker Socket Security Risks

The Docker socket mount (`/var/run/docker.sock`) is required for workflows that build Docker images or run containers, but it comes with significant security trade-offs:

**What Docker Socket Access Means:**
- The container can perform ANY Docker operation on the host
- Full access to all containers, images, networks, and volumes
- Ability to mount any host directory into containers
- Potential to create privileged containers with full host access
- Access to Docker daemon configuration and secrets

### Risk Mitigation Strategies

**1. Isolation and Environment Controls:**
- Deploy only on dedicated hosts without sensitive data
- Use isolated networks away from production systems
- Avoid running on shared infrastructure or cloud instances with sensitive workloads
- Consider dedicated build servers with restricted network access

**2. Access Controls:**
- Limit repository access to trusted users only
- Review all workflow files before execution
- Use GitHub's branch protection and required reviews
- Implement runner groups to control which repositories can access runners

**3. Alternative Security Approaches:**
- **Docker Socket Proxy**: Use a docker socket proxy to filter dangerous Docker API calls
- **Rootless Docker**: Run Docker daemon in rootless mode on the host
- **Container-as-a-Service**: Use platforms with built-in isolation
- **GitHub-hosted runners**: For public repositories or less sensitive workloads

**4. Monitoring and Detection:**
- Monitor Docker API calls and container creation
- Alert on privileged container creation or suspicious mounts
- Track network connections and file system access
- Implement log aggregation for security analysis

### Best Practices

1. **Use repository-specific runners** for sensitive projects
2. **Rotate tokens regularly** and never commit them to version control
3. **Limit runner access** using GitHub's runner groups
4. **Monitor runner logs** for suspicious activity
5. **Keep the image updated** with security patches
6. **Review workflow permissions** and limit to minimum required
7. **Implement network segmentation** to isolate runner traffic

### Network Isolation

For enhanced security, run runners in an isolated network:

```yaml
networks:
  runner-network:
    driver: bridge
    internal: true  # No external access

services:
  github-runner:
    networks:
      - runner-network
```

### Read-Only Root Filesystem

For additional security, make the root filesystem read-only:

```yaml
services:
  github-runner:
    read_only: true
    tmpfs:
      - /tmp
      - /home/runner/_work
```

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is provided as-is for use with GitHub Actions self-hosted runners.

## Support

No support will be provided at this time, I don't have time to manage it.