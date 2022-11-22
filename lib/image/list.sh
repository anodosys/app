#!/bin/bash -e

imageList()
{
  docker image ls -a | awk '{print $1,$2,$3}' | tail -n +2 | sort -n
}

# shellcheck disable=SC2034
typeset -fx imageList
