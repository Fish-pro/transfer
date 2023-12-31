#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

PULLER_GO_PACKAGE="github.com/daocloud/dsp-appserver"

PULLER_TARGET_SOURCE=(
  apiserver=cmd/apiserver
)

# This script holds common bash variables and utility functions.

# This function installs a Go tools by 'go install' command.
# Parameters:
#  - $1: package name, such as "sigs.k8s.io/controller-tools/cmd/controller-gen"
#  - $2: package version, such as "v0.8.0"
function util::install_tools() {
	local package="$1"
	local version="$2"
	echo "go install ${package}@${version}"
	GO111MODULE=on go install "${package}"@"${version}"
	GOPATH=$(go env GOPATH | awk -F ':' '{print $1}')
	export PATH=$PATH:$GOPATH/bin
}

function util:host_platform() {
  echo "$(go env GOHOSTOS)/$(go env GOHOSTARCH)"
}

function util::get_target_source() {
  local target=$1
  for s in "${PULLER_TARGET_SOURCE[@]}"; do
    if [[ "$s" == ${target}=* ]]; then
      echo "${s##${target}=}"
      return
    fi
  done
}

function util::version_ldflags() {
  # Git information
  GIT_VERSION=$(util::get_version)
  GIT_COMMIT_HASH=$(git rev-parse HEAD)
  if git_status=$(git status --porcelain 2>/dev/null) && [[ -z ${git_status} ]]; then
    GIT_TREESTATE="clean"
  else
    GIT_TREESTATE="dirty"
  fi
  BUILDDATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
  LDFLAGS="-X github.com/daocloud/dsp-appserver/pkg/version.gitVersion=${GIT_VERSION} \
                        -X github.com/daocloud/dsp-appserver/pkg/version.gitCommit=${GIT_COMMIT_HASH} \
                        -X github.com/daocloud/dsp-appserver/pkg/version.gitTreeState=${GIT_TREESTATE} \
                        -X github.com/daocloud/dsp-appserver/pkg/version.buildDate=${BUILDDATE}"
  echo $LDFLAGS
}

function util::get_version() {
  git describe --tags --dirty
}

