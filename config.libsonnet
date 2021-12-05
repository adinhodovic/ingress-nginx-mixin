{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    ingressNginxSelector: 'job="ingress-nginx-controller-metrics"',
    grafanaUrl: 'https://grafana.com',
    overviewDashboardUid: 'ingress-nginx-overview-12mk4klgjweg',
    requestHandlingPerformanceDashboardUid: 'ingress-nginx-request-jqkwfdqwd',
    tags: ['nginx', 'ingress-nginx'],
    ignoredIngresses: '',
    ingressNginx4xxInterval: '5m',
    ingressNginx4xxThreshold: '5',  // percent
    ingressNginx5xxInterval: '5m',
    ingressNginx5xxThreshold: '5',  // percent
  },
}
