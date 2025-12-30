#!/bin/bash -e

imageList()
{
  docker images --format "{{.Repository}} {{.Tag}} {{.ID}}" | sort -n
}

# shellcheck disable=SC2034
typeset -fx imageList
