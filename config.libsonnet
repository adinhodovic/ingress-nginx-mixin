{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    ingressNginxSelector: 'job="ingress-nginx-controller-metrics"',
    grafanaUrl: 'https://grafana.com',
    overviewDashboardUid: 'ingress-nginx-overview-12mk4klgjweg',
    dashboardLabelQueryParams: 'var-exported_namespace={{ $labels.exported_namespace }}&var-ingress={{ $labels.ingress }}',
    dashboardUrl: '%s/d/%s/nginx-ingress-controller?%s' % [self.grafanaUrl, self.overviewDashboardUid, self.dashboardLabelQueryParams],
    requestHandlingPerformanceDashboardUid: 'ingress-nginx-request-jqkwfdqwd',
    tags: ['nginx', 'ingress-nginx'],
    ignoredIngresses: '',
    ingressNginx4xxSeverity: 'info',
    ingressNginx4xxInterval: '5m',
    ingressNginx4xxThreshold: '5',  // percent
    ingressNginx5xxSeverity: 'warning',
    ingressNginx5xxInterval: '5m',
    ingressNginx5xxThreshold: '5',  // percent
  },
}
