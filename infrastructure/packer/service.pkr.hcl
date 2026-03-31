packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.0"
    }
  }
}

source "docker" "arm64" {
  changes     = [
    "EXPOSE 3000",
    "CMD [\"/usr/local/bin/entrypoint.sh\"]"
  ]
  commit      = "true"
  image       = "debian:12-slim"
  run_command = ["-d", "-i", "-t", "-v", "/var/run/docker.sock:/var/run/docker.sock", "--name", "packer-poiesis-service-arm64", "{{.Image}}", "/bin/bash"]
  platform    = "linux/arm64/v8"
}

source "docker" "amd64" {
  changes     = [
    "EXPOSE 3000",
    "CMD [\"/usr/local/bin/entrypoint.sh\"]"
  ]
  commit      = "true"
  image       = "debian:12-slim"
  run_command = ["-d", "-i", "-t", "-v", "/var/run/docker.sock:/var/run/docker.sock", "--name", "packer-poiesis-service-amd64", "{{.Image}}", "/bin/bash"]
  platform    = "linux/amd64"
}

build {
  sources = [
    "source.docker.arm64",
    "source.docker.amd64",
  ]

  provisioner "shell" {
    script = "bin/setup-image-requirements"
  }

  provisioner "ansible" {
    extra_arguments = ["--extra-vars", "ansible_host=packer-poiesis-service-${source.name} ansible_connection=docker"]
    playbook_file   = "infrastructure/ansible/playbook-service.yml"
    user            = "root"
  }

  post-processor "docker-tag" {
    repository = "svanosselaer/poiesis-service"
    tags       = ["${source.name}"]
  }
}
