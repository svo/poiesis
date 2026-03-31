---
name: run-service
description: Starts one or more project services locally using their Docker images. Reads the docker-tag from each service's infrastructure/packer/service.pkr.hcl to determine the image name. Use when the user wants to run, start, or restart a specific service.
disable-model-invocation: true
allowed-tools: Bash(*)
---

# Run Service

Start a project service locally using its Docker image.

## Usage

`/run-service <service-name>` or `/run-service all`

## Resolving the Docker Image Name

Each service's image name is defined by the `docker-tag` variable in its Packer config:

```bash
docker_tag=$(grep -oP 'docker-tag\s*=\s*"\K[^"]+' services/$0/infrastructure/packer/service.pkr.hcl)
```

## Steps for Backend Services

1. Resolve the Docker image name from `services/$0/infrastructure/packer/service.pkr.hcl`.

2. Build the image if not already built:
   ```bash
   cd services/$0
   docker build -t ${docker_tag} .
   ```

3. Look up the assigned port from the Vagrantfile or CLAUDE.md.

4. Run the container:
   ```bash
   docker run -d \
     --name ${PROJECT_NAME}-$0 \
     -p $PORT:$PORT \
     -e PORT=$PORT \
     -e HOST=0.0.0.0 \
     ${docker_tag}
   ```

## Steps for Frontend

1. Resolve the Docker image name from `ui/infrastructure/packer/service.pkr.hcl`.

2. Build and run, passing backend service URLs as environment variables:
   ```bash
   cd ui
   docker build -t ${docker_tag} .
   docker run -d \
     --name ${PROJECT_NAME}-ui \
     -p 3000:3000 \
     -e PORT=3000 \
     ${docker_tag}
   ```

   Read the frontend's configuration or `.env` file to determine which `NEXT_PUBLIC_*` variables to pass.

## Running All Services

If `$0` is `all`, iterate over each service directory, resolve its `docker-tag`, build and run each container in sequence. Start backend services first, then the frontend.

## Stopping Services

```bash
docker stop ${PROJECT_NAME}-$0 && docker rm ${PROJECT_NAME}-$0
```

Or to stop all:
```bash
docker ps --filter "name=${PROJECT_NAME}-" -q | xargs docker stop | xargs docker rm
```
