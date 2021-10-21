{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'nginx.rules',
        rules: [
          {
            alert: 'NginxHighHttp4xxErrorRate',
            expr: |||
              (sum(rate(nginx_ingress_controller_requests{%(ingressNginxSelector)s, status=~"^4.*", ingress!~"%(ignoredIngresses)s"}[%(interval)s]))  by (exported_namespace, ingress) / sum(rate(nginx_ingress_controller_requests{%(ingressNginxSelector)s, ingress!~"%(ignoredIngresses)s"}[%(interval)s]))  by (exported_namespace, ingress) * 100) > %(threshold)s
            ||| % $._config,
            'for': '30s',
            labels: {
              severity: 'info',
            },
            annotations: {
              summary: 'Nginx high HTTP 4xx error rate.',
              description: 'More than %(threshold)s%% HTTP requests with status 4xx for {{ $labels.ingress }}/{{ $labels.exported_namespace }} the past %(interval)s.' % $._config,
              dashboard_url: '%(grafanaUrl)s/d/%(overviewDashboardUid)s/nginx-ingress-controller?orgId=1&refresh=5s' % $._config,
            },
          },
          {
            alert: 'NginxHighHttp5xxErrorRate',
            expr: |||
              (sum(rate(nginx_ingress_controller_requests{%(ingressNginxSelector)s, status=~"^5.*", ingress!~"%(ignoredIngresses)s"}[%(interval)s]))  by (exported_namespace, ingress) / sum(rate(nginx_ingress_controller_requests{%(ingressNginxSelector)s, ingress!~"%(ignoredIngresses)s"}[%(interval)s]))  by (exported_namespace, ingress) * 100) > %(threshold)s
            ||| % $._config,
            annotations: {
              summary: 'Nginx high HTTP 5xx error rate.',
              description: 'More than %(threshold)s%% HTTP requests with status 5xx for {{ $labels.ingress }}/{{ $labels.exported_namespace }} the past %(interval)s.' % $._config,
              dashboard_url: '%(grafanaUrl)s/d/%(overviewDashboardUid)s/nginx-ingress-controller?orgId=1&refresh=5s' % $._config,
            },
            'for': '30s',
            labels: {
              severity: 'warning',
            },
          },
        ],
      },
    ],
  },
}
