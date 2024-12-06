# Argo CD Chart

A Helm chart for Argo CD, a declarative, GitOps continuous delivery tool for Kubernetes.

Source code can be found here:

* <https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd>
* <https://github.com/argoproj/argo-cd>

This is a **community maintained** chart. This chart installs [argo-cd](https://argo-cd.readthedocs.io/en/stable/), a declarative, GitOps continuous delivery tool for Kubernetes.

The default installation is intended to be similar to the provided Argo CD [releases](https://github.com/argoproj/argo-cd/releases).

If you want to avoid including sensitive information unencrypted (clear text) in your version control, make use of the [declarative setup] of Argo CD.
For instance, rather than adding repositories and their keys in your Helm values, you could deploy [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets) with contents as seen in this [repositories section](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#repositories) or any other secrets manager service (i.e. HashiCorp Vault, AWS/GCP Secrets Manager, etc.).

## High Availability

This chart installs the non-HA version of Argo CD by default. If you want to run Argo CD in HA mode, you can use one of the example values in the next sections.
Please also have a look into the upstream [Operator Manual regarding High Availability](https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/) to understand how scaling of Argo CD works in detail.

> **Warning:**
> You need at least 3 worker nodes as the HA mode of redis enforces Pods to run on separate nodes.

```yaml
controller:
  replicas: 1

server:
  replicas: 2

repoServer:
  replicas: 2

applicationSet:
  replicas: 2
```

## Ingress configuration

Please refer to the [Operator Manual](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#ingress-configurationh) for details as the samples
below corespond to their respective sections.

### SSL-Passthrough

The `tls: true` option will expect that the `argocd-server-tls` secret exists as Argo CD server loads TLS certificates from this place.

```yaml
global:
  domain: argocd.example.com

certificate:
  enabled: true

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    tls: true
```

### SSL Termination at Ingress Controller

```yaml
global:
  domain: argocd.example.com

configs:
  params:
    server.insecure: true

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    extraTls:
      - hosts:
        - argocd.example.com
        # Based on the ingress controller used secret might be optional
        secretName: wildcard-tls
```

> **Note:**
> If you don't plan on using a wildcard certificate it's also possible to use `tls: true` without `extraTls` section.

### Multiple ingress resources for gRPC protocol support

Use `ingressGrpc` section if your ingress controller supports only a single protocol per Ingress resource (i.e.: Contour).

```yaml
global:
  domain: argocd.example.com

configs:
  params:
    server.insecure: true

server:
  ingress:
    enabled: true
    ingressClassName: contour-internal
    extraTls:
      - hosts:
        - argocd.example.com
        secretName: wildcard-tls

   ingressGrpc:
     enabled: true
     ingressClassName: contour-internal
     extraTls:
      - hosts:
        - grpc.argocd.example.com
        secretName: wildcard-tls
```

### Multiple ingress domains

```yaml
global:
  domain: argocd.example.com

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: "<my-issuer>"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    tls: true
    extraHosts:
      - name: argocd-alias.example.com
        path: /
```

### AWS Application Load Balancer

Refer to the Operator Manual for [AWS Application Load Balancer mode](https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/#aws-application-load-balancers-albs-and-classic-elb-http-mode).
The provided example assumes you are using TLS off-loading via AWS ACM service.

> **Note:**
> Using `controller: aws` creates additional service for gRPC traffic and it's no longer need to use `ingressGrpc` configuration section.

```yaml
global:
  domain: argocd.example.com

configs:
  params:
    server.insecure: true

server:
  ingress:
    enabled: true
    controller: aws
    ingressClassName: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internal
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/backend-protocol: HTTP
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":80}, {"HTTPS":443}]'
      alb.ingress.kubernetes.io/ssl-redirect: '443'
    aws:
      serviceType: ClusterIP # <- Used with target-type: ip
      backendProtocolVersion: GRPC
```

### GKE Application Load Balancer

The implementation will populate `ingressClassName`, `networking.gke.io/managed-certificates` and `networking.gke.io/v1beta1.FrontendConfig` annotations
automatically if you provide configuration for GKE resources.

```yaml
global:
  domain: argocd.example.com

configs:
  params:
    server.insecure: true

server:
  service:
    annotations:
      cloud.google.com/neg: '{"ingress": true}'
      cloud.google.com/backend-config: '{"ports": {"http":"argocd-server"}}'

  ingress:
    enabled: true
    controller: gke
    gke:
      backendConfig:
        healthCheck:
          checkIntervalSec: 30
          timeoutSec: 5
          healthyThreshold: 1
          unhealthyThreshold: 2
          type: HTTP
          requestPath: /healthz
          port: 8080
      frontendConfig:
        redirectToHttps:
          enabled: true 
      managedCertificate:
        enabled: true
```

## Synchronizing Changes from Original Repository

In the original [Argo CD repository](https://github.com/argoproj/argo-cd/) an [`manifests/install.yaml`](https://github.com/argoproj/argo-cd/blob/master/manifests/install.yaml) is generated using `kustomize`. It's the basis for the installation as [described in the docs](https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd).

When installing Argo CD using this helm chart the user should have a similar experience and configuration rolled out. Hence, it makes sense to try to achieve a similar output of rendered `.yaml` resources when calling `helm template` using the default settings in `values.yaml`.

To update the templates and default settings in `values.yaml` it may come in handy to look up the diff of the `manifests/install.yaml` between two versions accordingly. This can either be done directly via github and look for `manifests/install.yaml`:

https://github.com/argoproj/argo-cd/compare/v1.8.7...v2.0.0#files_bucket

Or you clone the repository and do a local `git-diff`:

```bash
git clone https://github.com/argoproj/argo-cd.git
cd argo-cd
git diff v1.8.7 v2.0.0 -- manifests/install.yaml
```

Changes in the `CustomResourceDefinition` resources shall be fixed easily by copying 1:1 from the [`manifests/crds` folder](https://github.com/argoproj/argo-cd/tree/master/manifests/crds) into this [`charts/argo-cd/templates/crds` folder](https://github.com/argoproj/argo-helm/tree/master/charts/argo-cd/templates/crds).

### Custom resource definitions

Some users would prefer to install the CRDs _outside_ of the chart. You can disable the CRD installation of this chart by using `--set crds.install=false` when installing the chart.

Helm cannot upgrade custom resource definitions in the `<chart>/crds` folder [by design](https://helm.sh/docs/chart_best_practices/custom_resource_definitions/#some-caveats-and-explanations). Starting with 5.2.0, the CRDs have been moved to `<chart>/templates` to address this design decision.

If you are using Argo CD chart version prior to 5.2.0 or have elected to manage the Argo CD CRDs outside of the chart, please use `kubectl` to upgrade CRDs manually from [templates/crds](templates/crds/) folder or via the manifests from the upstream project repo:

```bash
kubectl apply -k "https://github.com/argoproj/argo-cd/manifests/crds?ref=<appVersion>"

# Eg. version v2.4.9
kubectl apply -k "https://github.com/argoproj/argo-cd/manifests/crds?ref=v2.4.9"
```
