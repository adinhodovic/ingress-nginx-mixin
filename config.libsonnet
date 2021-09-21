{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    ingressNginxSelector: 'job="ingress-nginx-controller-metrics"',
    grafanaUrl: 'https://grafana.com',
    overviewDashboardUid: '4x6xvSN7z',
    ignoredIngresses: '',
  },
}
