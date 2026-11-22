source "docker" "fixture-ui-service" {
  image  = "node:24-slim"
  commit = true
}

build {
  sources = ["source.docker.fixture-ui-service"]

  post-processor "docker-tag" {
    repository = "svanosselaer/fixture-ui-service"
    tags       = ["latest"]
  }
}
