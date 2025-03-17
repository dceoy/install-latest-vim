variable "REGISTRY" {
  default = "docker.io/dceoy"
}

variable "TAG" {
  default = "latest"
}

variable "UBUNTU_VERSION" {
  default = "24.04"
}

variable "PYTHON_VERSION" {
  default = "3.13"
}

variable "USER_NAME" {
  default = "cli"
}

variable "USER_UID" {
  default = 1001
}

variable "USER_GID" {
  default = 1001
}

group "default" {
  targets = ["vim"]
}

target "vim" {
  tags       = ["${REGISTRY}/vim:${TAG}"]
  context    = "."
  dockerfile = "Dockerfile"
  target     = "app"
  platforms  = ["linux/arm64"]
  args = {
    UBUNTU_VERSION = UBUNTU_VERSION
    PYTHON_VERSION = PYTHON_VERSION
    USER_NAME      = USER_NAME
    USER_UID       = USER_UID
    USER_GID       = USER_GID
  }
  cache_from = ["type=gha"]
  cache_to   = ["type=gha,mode=max"]
  pull       = true
  push       = false
  load       = true
  provenance = false
}
