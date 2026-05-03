# K3s Homelab Cluster

This repo contains an ansible playbook, k8s manifests, and examples of simple deployments to easily get a k3s cluster up in a homelab environment.

## Prerequisites

### Compute Prerequisites

1. 3 or more nodes to join the cluster
    - See [the official K3s Requirements documentation](https://docs.k3s.io/installation/requirements#server-sizing-guide) for sizing details.
2. Nodes **must** run a RHEL alike ala Rocky or Alama Linux
    - Minimum version 9
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

This repo is configured to use `ansible-pull` to automate k3s server creation at provisoning time.

To create a k3s cluster first variables and hosts must be configured then the playbook is used to deploy the cluster.

### Configuring a cluster

The cluster is configured via `host_vars`. See `ansible/host_vars/localhost.example`

#### host_vars Configuration Options

Deployed clusters are configured through a set of host variables. These variables control cluster wide values such as the k3s token and which features are enabled on the depolyed cluster.

##### Cluster Parameters

> **k3s_token** - The token to pass to the k3s init command. `pwgen 24 -y -s | base64`

> **control_cidr** - The CIDR to allow 6443 access for kubectl outside the cluster.

##### kube-vip 

kube-vip provides a highly avialable control plane IP.

> **vip** - Enable/disable kube-vip

> **vip_ip** - IP for cluster VIP.

##### metallb

metallb is used as a service load balancer. This provides IPs for services running in the cluster.

> **metallb** - Enable/disable MetalLB as service load balancer.

> **metallb_range** - IP range MetalLB can assign to services.

> **metallb_manifest_path** - Path to the manifests for metallb

##### traefik

traefik is used for ssl termination, path based routing, and middlewares.

> **traefik_cf_le** - Enable/disable acme letsencrypt certificates. **By default this playbook uses the LE Staging CA.**

> **traefik_fqdn** - FQDN to access traefik via service load balancer.

> **traefik_manifest_path** - Path to the manifests for traefik.

##### secrets

> **secrets_path** - Path to sops encrypted `*.enc.yaml` files.

Secrets use [sops](https://github.com/getsops/sops) to encrypt values in the yaml files. The master node **must** have a corresponding way to decrypt this secret. 

The playbook copies any `*.enc.yaml` files in the `secrets_path` to the master node and uses sops to decrypt it.

```
$ sops -e secret/cloudflare.yaml.example > secret/cloudflare.enc.yaml.example
```

##### monitoring

Monitoring uses the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) Helm chart to deploy Prometheus, Grafana, Alertmanager, and related exporters.

> **monitoring** - Enable/disable monitoring stack.

> **monitoring_manifest_path** - Path to the manifests for monitoring configuration.

> **grafana_fqdn** - FQDN to access Grafana via Traefik ingress.

> **prometheus_retention** - Prometheus data retention period (default: 15d).

> **prometheus_storage** - Prometheus persistent storage size.

> **grafana_storage** - Grafana persistent storage size.

##### ArgoCD

> **NOTE:** This requires having Traefik configured with LetsEncrypt.

ArgoCD can be deployed to the cluster.

> **argocd** - Enable/disable ArgoCD deployment

> **argocd_manifests_path** - Path to ArgoCD manifests to use.

> **argocd_fqdn** - FQDN of ArgoCD.

> **argocd_ha** - Enable/disable ArgoCD in HA mode.

##### System Update Controller (SUC)

> **system_update** - Enable/disable the system-update-controller to automatically update the k3s stack to latest stable.

##### External Load Balancer (optional)

An external load balancer can be used for SSL termination and routing if desired.

The `haproxy` folder contains an example container configuration for an external LB.

> **ext_lb** - Enable/disable an external load balancer. (Optional)

> **lb_ip** - The IP of the external load balancer.

> **lb_dns** - The FQDN of the external load balancer.


### Deploying a cluster

#### Deploy Master Node

A master node is a server node and the first node in the cluster.

> **NOTE:** This playbook supports kickstarting the master node. To enable this set `-e "kickstart=true` in the `ansible-pull` command. This will run the bootstrap service on first boot rather than immediately.

The master node is responsible for bootstrapping the cluster. This node applies the initial configurations to provide minium configuration for further nodes to join.

1. Run the ansible playbook setting the `node_role` variable
    - `ansible-pull -d /etc/local/ansible -C 'ansible-pull' -U https://github.com/Smurf/k3s-cluster.git -e "node_role=master" ansible/local.yml`
    - This will start `k3s-bootstrap.service` immediately and begin to configure the first node.
2. `kubectl get nodes` should show the master node
3. `kubectl get svc -A`
    - Traefik should be accessable via https at the External-IP shown.


#### Deploy a Server Node

Server nodes run the control plane and workloads. Clusters should contain a minimum of three server nodes.

To deploy a server node simply pull the playbook with the appropriate role selected.
```
ansible-pull -d /etc/local/ansible -C 'ansible-pull' -U https://github.com/Smurf/k3s-cluster.git -e "node_role=server" ansible/local.yml
```

#### Deploy a Agnet Node

Agent nodes only run workloads.
```
ansible-pull -d /etc/local/ansible -C 'ansible-pull' -U https://github.com/Smurf/k3s-cluster.git -e "node_role=agent" ansible/local.yml
```

### Deploying A Test Application

This repo contains a simple hello world application to test traefik's web and websecure endpoints. This ensures that automatic LE certificate issuance is working.

#### Simple Hello World

1. `kubectl apply -f examples/hello-world/config-map.yaml`
2. `kubectl apply -f examples/hello-world/hello-world.yaml`
3. A simple html page should now be available at `http://$traefik_ip/hello`

#### HTTPS Hello World via LetsEncrypt and Cloudflare

This repo contains configuration for using cloudflare DNS and letsencrypt to create certificates for all routes with a `Host` rule.

1. Ensure that the `cloudflare-api-token-secret` exists
    - `kubectl get secrets --all-namespaces | grep cloudflare`
    - This secret should be automatically provisioned via ansible the master node and applied using `sops`. See the [secrets configuration section](#secrets) for details
2. Edit `examples/hello-world/tls/hello-world.yaml` to point to your own FQDN.
    - Ensure a DNS entry exists
2. `kubectl apply -f examples/hello-world/config-map.yaml`
3. `kubectl apply -f examples/hello-world/tls/hello-world.yaml`
4. A simple https hello world page will now show at the FQDN set.
