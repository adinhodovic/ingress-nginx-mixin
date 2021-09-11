# Prometheus Monitoring Mixin for Ingress-nginx

A set of Grafana dashboards and Prometheus alerts and rules for ingress-nginx.

## How to use

This mixin is designed to be vendored into the repo with your infrastructure config.
To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards

1. Generate the config files and deploy them yourself
2. Use jsonnet to deploy this mixin along with Prometheus and Grafana
3. Use prometheus-operator to deploy this mixin

## Generate config files

You can manually generate the alerts, dashboards and rules files, but first you
must install some tools:

```sh
go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
brew install jsonnet
```

Then, grab the mixin and its dependencies:

```sh
git clone https://github.com/example/ingress-nginx-mixin
cd example/ingress-nginx-mixin
jb install
```

Finally, build the mixin:

```sh
make prometheus-alerts.yaml
make prometheus-rules.yaml
make dashboards-out
```

The prometheus-alerts.yaml and prometheus-rules.yaml file then need to passed to your Prometheus server, and the files in dashboards-out need to be imported into you Grafana server. The exact details will depending on how you deploy your monitoring stack to Kubernetes.

## Alerts

The mixin follows the [monitoring-mixins guidelines](https://github.com/monitoring-mixins/docs#guidelines-for-alert-names-labels-and-annotations) for alerts.
