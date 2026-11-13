#!/bin/bash -e

# Configures the Nginx of the status container of the proxy, run by its install command after "cosyses Nginx 1.30".
# The workers run as www-data, which Anodosys adds to the group of the Docker socket (volume mode r).

sed -i "s/^user .*/user www-data;/" /etc/nginx/nginx.conf
ln -sf /etc/anodosys-status/nginx.conf /etc/nginx/conf.d/anodosys-status.conf
nginx -t
