#! /bin/bash

 podman run -d --replace --name k3s-lb -v $PWD/conf/:/usr/local/etc/haproxy:ro -p 80:80 -p 6443:6443 haproxy:2.3
