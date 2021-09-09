{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    ingressNginxMixinSelector: 'job="ingress-nginx-controller-metrics"',
  },
}
