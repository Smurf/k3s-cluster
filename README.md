# K3s Homelab Cluster

This repo contains an ansible playbook, k8s manifests, and examples of simple deployments to easily get a k3s cluster up in a homelab environment.

> **NOTE:** Currently this does not support agent ndoes. All nodes are master nodes.

## Prerequisites

### Compute Prerequisites

1. 3 or more nodes to join the cluster
    - See [the official K3s Requirements documentation](https://docs.k3s.io/installation/requirements#server-sizing-guide) for sizing details.
    - Since all nodes are server nodes some extra resources are required.
2. Nodes **must** run a RHEL alike ala Rocky or Alama Linux
3. ssh access to each node
4. root privileges on each node

### Network Prerequisites

1. All nodes must be able to reach one another 
    - [The official K3s networking documentation](https://docs.k3s.io/installation/requirements#networking) covers the port requiremnts.
    - The ansible playbook automatically opens the required ports on the nodes.
2. If using MetalLB - You must have an open IP range for MetalLB to use.
    - /26 is nice and easy but it can be an arbirary range.
3. If using kube-vip
    - There must be an open IP for the VIP of the cluster

## Using This Repo

To create a k3s cluster first variables and hosts must be configured then the playbook is used to deploy the cluster.

### Configuring a cluster

The cluster is configured via an inventory and group variables files.

1. Create an inventory.
    - See `ansible/inventory/cluster-inv.yaml.example`
2. Set up variables for your cluster.
    - See `ansible/group-vars/cluster.example`

#### Configuration Options

> **k3s_token** - The token to pass to the k3s init command. `pwgen 24 -y -s | base64`

> **control_cidr** - The CIDR to allow 6443 access for kubectl outside the cluster.

> **ext_lb** - Enable/disable an external load balancer.
    - The `haproxy` folder contains an example container configuration for an external LB.
> **lb_ip** - The IP of the external load balancer.
> **lb_dns** - The FQDN of the external load balancer.

> **vip** - Enable/disable kube-vip
> **vip_ip** - IP for cluster VIP

> **metallb** - Enable/disable MetalLB as service load balancer.
> **metallb_range** - IP range MetalLB can assign to services.
> **metallb_manifest_path** - Path to the manifests for metallb

> **traefik_cf_le** - Enable/disable acme letsencrypt certificates.
> **traefik_fqdn** - FQDN to access traefik via service load balancer.
> **traefik_manifest_path** - Path to the manifests for traefik.

### Letsencrypt certificates

See `secret/cloudflare.yaml.example` for an example yaml file.

> **NOTE:** These values are **base64** encoded. `echo -n $value | base64`

### Deploying a cluster

1. Run the ansible playbook
    - `ansible-playbook ansible/lab-cluster.yaml -i ansible/inventory/cluster-inv.yaml -u root`
    - If key based auth is not configured adding `--ask-pass`
    - If a non-root user is used to authenticate `--become` may be required.
2. Copy the kubectl from the fist node to `~/.kube/config` and modify the `server` value to the `kube-vip` IP
    - Optionally you may run the haproxy container on your own device to round robin nodes.
    - Optionally but not recommended you may just use the IP of the first node.
3. `k get nodes` should show all nodes in the cluster
4. `k get svc -A`
    - Traefik should be accessable via External-IP shown.

### Deploying A Test Application

#### Simple Hello World

1. `kubectl apply -f examples/hello-world/config-map.yaml`
2. `kubectl apply -f examples/hello-world/hello-world.yaml`
3. A simple html page should now be available at `http://$traefik_ip/hello`

#### HTTPS Hello World via LetsEncrypt and Cloudflare

This repo contains configuration for using cloudflare DNS and letsencrypt to create certificates for all routes with a `Host` rule.

1. Rename and edit `secret/cloudflare.yaml.example`
    - Add your CF API token and email address
2. Edit `examples/hello-world/tls/hello-world.yaml` to point to your own FQDN.
    - Ensure a DNS entry exists
2. `kubectl apply -f examples/hello-world/config-map.yaml`
3. `kubectl apply -f examples/hello-world/tls/hello-world.yaml`
4. A simple https hello world page will now show at the FQDN set.
