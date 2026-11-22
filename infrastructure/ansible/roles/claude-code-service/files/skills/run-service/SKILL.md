---
name: run-service
description: Starts, stops or restarts one or all of the project's services through the parent repository's Vagrantfile (Docker provider). Ports, image names and environment come from the Vagrantfile. Use when the user wants to run, start, stop, or restart a service.
disable-model-invocation: true
allowed-tools: Bash(vagrant *), Bash(docker image inspect *), Bash(grep *), Read
---

# Run Service

Start, stop or restart project services through the parent repository's `Vagrantfile`.

The Vagrantfile is the only place that says how a service runs. Each service has one `config.vm.define` block using the Docker provider, which names its image (`d.image`), its container (`d.name`), its host-to-guest port mapping (`d.ports`, host port = the project's host-port prefix followed by the guest port) and its environment (`d.env`, including the server-only URLs services use to reach each other). Do not start a service any other way: a container started by hand does not get those ports or that wiring.

## Usage

`/run-service <service-name>` or `/run-service all`

`<service-name>` is the name of a `config.vm.define` block in the Vagrantfile. List them with:

```bash
vagrant status
```

## Before starting: is the image built?

Vagrant runs an image; it does not build one. For each service you are about to start, read its `d.image` from the Vagrantfile and check that the image exists locally:

```bash
grep -n 'd.image' Vagrantfile
docker image inspect <image> > /dev/null
```

If the image is missing, stop and say so: name the service and its image, and tell the user to build it from the service's own repository with its build script, `./build-service.sh` in `services/<service-name>/` (or `ui/` for the frontend). Do not try to build it another way.

## Start

```bash
vagrant up <service-name>     # one service
vagrant up                    # every service in the Vagrantfile
```

When starting everything, start the backends before the frontend, so the frontend's API routes have something to reach:

```bash
vagrant up <backend-a> <backend-b>
vagrant up <frontend>
```

After starting, report each service's host port as the Vagrantfile declares it (the left side of `d.ports`).

## Restart

```bash
vagrant reload <service-name>
```

## Stop

```bash
vagrant halt <service-name>   # one service
vagrant halt                  # every service
```

To remove the containers as well:

```bash
vagrant destroy -f <service-name>
```
