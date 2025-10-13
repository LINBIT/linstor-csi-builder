variable "REGISTRY" {
  default = "nexus.at.linbit.com:5000"
}

variable "PLATFORMS" {
  default = "linux/amd64"
}

variable "SEMVER" {
  default = "0.0.0-unknown"
}

variable "TAG" {
  default = "latest"
}

variable REPO_SOURCE {
  default = ""
}

variable LINBIT_REPO {
  default = "/dev/null"
}

variable GOPROXY {
  default = ""
}

group "default" {
  targets = [
    "linstor-csi",
    "nfs-server",
  ]
}

function "escape" {
  params = [string]
  result = "${regex_replace(string, "[^a-zA-Z0-9_-]", "-")}"
}

function "platform_variants" {
  params = [platforms]
  result = concat([
    {
      prefix = ""
      platforms = split(",", platforms)
    }
  ], [
    for plat in split(",", platforms) :
    {
      prefix = "${trimprefix(plat, "linux/")}/"
      platforms = [plat]
    }
  ])
}

target "linstor-csi" {
  name = "${escape(platforms.prefix)}linstor-csi"
  tags = [
    "${REGISTRY}/${platforms.prefix}linstor-csi:${TAG}"
  ]
  matrix = {
    platforms = platform_variants(PLATFORMS)
  }
  args = {
    GOPROXY = GOPROXY
    REPO_SOURCE = REPO_SOURCE
    SEMVER = SEMVER
  }
  context   = "."
  platforms = platforms.platforms
}

target "nfs-server" {
  name = "${escape(platforms.prefix)}nfs-server"
  tags = [
    "${REGISTRY}/${platforms.prefix}nfs-server:${TAG}"
  ]
  matrix = {
    platforms = platform_variants(PLATFORMS)
  }
  args = {
    GOPROXY = GOPROXY
    REPO_SOURCE = REPO_SOURCE
    SEMVER = SEMVER
  }
  context   = "."
  dockerfile = "nfs/Dockerfile"
  platforms = platforms.platforms
  secret = [{
    type = "file"
    id = "linbit.repo"
    src = "${LINBIT_REPO}"
  }]
}
