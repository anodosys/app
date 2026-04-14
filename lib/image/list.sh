#!/bin/bash -e

imageList()
{
  docker images --all --format "{{.Repository}} {{.Tag}} {{.ID}}" | sort -n
}

# shellcheck disable=SC2034
typeset -fx imageList
