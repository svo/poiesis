source "docker" "-service" {
  image  = "node:24-slim"
  commit = true
}

build {
  sources = ["source.docker.-service"]

  post-processor "docker-tag" {
    repository = "svanosselaer/-service"
    tags       = ["latest"]
  }
}
