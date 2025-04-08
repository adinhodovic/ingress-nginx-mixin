{
  local clusterVariabletoAdd = if $._config.showMultiCluster then '&var-%(clusterLabel)s={{ $labels.%(clusterLabel)s}}' % $._config else '',
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'nginx.rules',
        rules: [
          {
            alert: 'NginxConfigReloadFailed',
            expr: |||
              sum(
                nginx_ingress_controller_config_last_reload_successful{%(ingressNginxSelector)s}
              ) by (job, controller_class, %(clusterLabel)s)
              == 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Nginx config reload failed.',
              description: 'Nginx config reload failed for the controller with the class {{ $labels.controller_class }}.',
              dashboard_url: $._config.overviewDashboardUrl + '?var-job={{ $labels.job }}&var-controller_class={{ $labels.controller_class }}' + clusterVariabletoAdd,
            },
          },
          {
            alert: 'NginxHighHttp4xxErrorRate',
            expr: |||
              (
                sum(
                  rate(
                    nginx_ingress_controller_requests{
                      %(ingressNginxSelector)s,
                      status=~"^4.*",
                      ingress!~"%(ignoredIngresses)s"
                    }[%(ingressNginx4xxInterval)s]
                  )
                ) by (exported_namespace, ingress, %(clusterLabel)s)
                /
                sum(
                  rate(
                    nginx_ingress_controller_requests{
                      %(ingressNginxSelector)s,
                      ingress!~"%(ignoredIngresses)s"
                    }[%(ingressNginx4xxInterval)s]
                  )
                ) by (exported_namespace, ingress, %(clusterLabel)s)
                * 100
              ) > %(ingressNginx4xxThreshold)s
            ||| % $._config,
            'for': '1m',
            labels: {
              severity: $._config.ingressNginx4xxSeverity,
            },
            annotations: {
              summary: 'Nginx high HTTP 4xx error rate.',
              description: 'More than %(ingressNginx4xxThreshold)s%% HTTP requests with status 4xx for {{ $labels.exported_namespace }}/{{ $labels.ingress }} the past %(ingressNginx4xxInterval)s.' % $._config,
              dashboard_url: $._config.overviewDashboardUrl + '?var-exported_namespace={{ $labels.exported_namespace }}&var-ingress={{ $labels.ingress }}' + clusterVariabletoAdd,
            },
          },
          {
            alert: 'NginxHighHttp5xxErrorRate',
            expr: |||
              (
                sum(
                  rate(
                    nginx_ingress_controller_requests{
                      %(ingressNginxSelector)s,
                      status=~"^5.*",
                      ingress!~"%(ignoredIngresses)s"
                    }[%(ingressNginx5xxInterval)s]
                  )
                ) by (exported_namespace, ingress, %(clusterLabel)s)
                /
                sum(
                  rate(
                    nginx_ingress_controller_requests{
                      %(ingressNginxSelector)s,
                      ingress!~"%(ignoredIngresses)s"
                    }[%(ingressNginx5xxInterval)s]
                  )
                ) by (exported_namespace, ingress, %(clusterLabel)s)
                * 100
              ) > %(ingressNginx5xxThreshold)s
            ||| % $._config,
            'for': '1m',
            annotations: {
              summary: 'Nginx high HTTP 5xx error rate.',
              description: 'More than %(ingressNginx5xxThreshold)s%% HTTP requests with status 5xx for {{ $labels.exported_namespace }}/{{ $labels.ingress }} the past %(ingressNginx5xxInterval)s.' % $._config,
              dashboard_url: $._config.overviewDashboardUrl + '?var-exported_namespace={{ $labels.exported_namespace }}&var-ingress={{ $labels.ingress }}' + clusterVariabletoAdd,
            },
            labels: {
              severity: $._config.ingressNginx5xxSeverity,
            },
          },
        ],
      },
    ],
  },
}
