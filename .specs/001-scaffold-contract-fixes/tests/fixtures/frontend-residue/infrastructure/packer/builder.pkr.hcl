build {
  post-processor "docker-tag" {
    repository = "svanosselaer/www-qual-is-builder"
    tags       = ["latest"]
  }
}
