local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local annotation = g.dashboard.annotation;

{
  _config+:: {
    // Bypasses grafana.com/dashboards validator
    bypassDashboardValidation: {
      __inputs: [],
      __requires: [],
    },

    // Selectors are inserted between {} in Prometheus queries.
    ingressNginxSelector: 'job=~"ingress-nginx-controller-metrics"',

    grafanaUrl: 'https://grafana.com',

    overviewDashboardUid: 'ingress-nginx-overview-12mk',
    requestHandlingPerformanceDashboardUid: 'ingress-nginx-request-handling-jqkw',

    overviewDashboardUrl: '%s/d/%s/ingress-nginx-overview' % [self.grafanaUrl, self.overviewDashboardUid],
    requestHandlingPerformanceDashboardUrl: '%s/d/%s/fix tis' % [
      self.grafanaUrl,
      self.requestHandlingPerformanceDashboardUid,
    ],  // TODO: fix this

    tags: ['ingress-nginx', 'ingress-nginx-mixin'],

    ignoredIngresses: '',
    ingressNginx4xxSeverity: 'info',
    ingressNginx4xxInterval: '5m',
    ingressNginx4xxThreshold: '5',  // percent
    ingressNginx5xxSeverity: 'warning',
    ingressNginx5xxInterval: '5m',
    ingressNginx5xxThreshold: '5',  // percent

    // Custom annotations to display in graphs
    annotation: {
      enabled: false,
      name: 'Custom Annotation',
      datasource: '-- Grafana --',
      iconColor: 'green',
      tags: [],
    },

    customAnnotation:: if $._config.annotation.enabled then
      annotation.withName($._config.annotation.name) +
      annotation.withIconColor($._config.annotation.iconColor) +
      annotation.withHide(false) +
      annotation.datasource.withUid($._config.annotation.datasource) +
      annotation.target.withMatchAny(true) +
      annotation.target.withTags($._config.annotation.tags) +
      annotation.target.withType('tags')
    else {},
  },
}
