{

  local requestHandlingPerformanceDashboardTemplates = [
    prometheusTemplate,
    template.new(
      name='exported_namespace',
      label='Ingress Namespace',
      datasource='$datasource',
      query='label_values(nginx_ingress_controller_requests, exported_namespace)',
      current='',
      hide='',
      refresh=1,
      multi=false,
      includeAll=false,
      sort=1
    ),
    template.new(
      name='ingress',
      label='Ingress',
      datasource='$datasource',
      query='label_values(nginx_ingress_controller_requests{exported_namespace=~"$exported_namespace"}, ingress)',
      current='',
      hide='',
      refresh=1,
      multi=true,
      includeAll=true,
      sort=1
    ),
    errorCodesTemplate,
  ],

  local ingressRequestHandlingTimeQuery = |||
    histogram_quantile(
      0.5,
      sum by (le, ingress, exported_namespace)(
        rate(
          nginx_ingress_controller_request_duration_seconds_bucket{
            ingress =~ "$ingress",
            exported_namespace=~"$exported_namespace"
          }[$__rate_interval]
        )
      )
    )
  ||| % $._config,

  local ingressRequestHandlingTimeGraphPanel =
    graphPanel.new(
      'Total Request Time',
      datasource='$datasource',
      format='s',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressRequestHandlingTimeQuery,
        legendFormat='.5 - {{ ingress }}/{{ exported_namespace }}',
      )
    )
    .addTarget(
      prometheus.target(
        std.strReplace(ingressRequestHandlingTimeQuery, '0.5', '0.95'),
        legendFormat='.95 - {{ ingress }}/{{ exported_namespace }}',
      )
    )
    .addTarget(
      prometheus.target(
        std.strReplace(ingressRequestHandlingTimeQuery, '0.5', '0.99'),
        legendFormat='.99 - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressUpstreamResponseTimeQuery = |||
    histogram_quantile(
      0.5,
      sum by (le, ingress, exported_namespace)(
        rate(
          nginx_ingress_controller_response_duration_seconds_bucket{
            ingress =~ "$ingress",
            exported_namespace=~"$exported_namespace"
          }[$__rate_interval]
        )
      )
    )
  ||| % $._config,

  local ingressUpstreamResponseTimeGraphPanel =
    graphPanel.new(
      'Upstream Response Time',
      datasource='$datasource',
      format='s',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressUpstreamResponseTimeQuery,
        legendFormat='.5 - {{ ingress }}/{{ exported_namespace }}',
      )
    )
    .addTarget(
      prometheus.target(
        std.strReplace(ingressUpstreamResponseTimeQuery, '0.5', '0.95'),
        legendFormat='.95 - {{ ingress }}/{{ exported_namespace }}',
      )
    )
    .addTarget(
      prometheus.target(
        std.strReplace(ingressUpstreamResponseTimeQuery, '0.5', '0.99'),
        legendFormat='.99 - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressRequestVolumeQuery = |||
    sum by (path, ingress, exported_namespace)(
      rate(
        nginx_ingress_controller_request_duration_seconds_count{
          ingress =~ "$ingress",
          exported_namespace=~"$exported_namespace"
        }[$__rate_interval]
      )
    )
  ||| % $._config,

  local ingressRequestVolumeByPathGraphPanel =
    graphPanel.new(
      'Request Volume',
      datasource='$datasource',
      format='reqps',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressRequestVolumeQuery,
        legendFormat='{{ path }} - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressUpstreamMedianResponseTimeQuery = |||
    histogram_quantile(
      .5,
      sum by (le, path, ingress, exported_namespace)(
        rate(
          nginx_ingress_controller_response_duration_seconds_bucket{
            ingress =~ "$ingress",
            exported_namespace=~"$exported_namespace"
          }[$__rate_interval]
        )
      )
    )
  ||| % $._config,

  local ingressUpstreamMedianResponseTimeGraphPanel =
    graphPanel.new(
      'Median upstream response time',
      datasource='$datasource',
      format='s',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressUpstreamMedianResponseTimeQuery,
        legendFormat='{{ path }} - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressResponseErrorRateQuery = |||
    sum by (path, ingress, exported_namespace) (
      rate(
        nginx_ingress_controller_request_duration_seconds_count{
          ingress=~"$ingress",
          exported_namespace=~"$exported_namespace",
          status=~"[$error_codes].*"
        }[$__rate_interval]
      )
    )
    /
    sum by (path, ingress, exported_namespace) (
      rate(
        nginx_ingress_controller_request_duration_seconds_count{
          ingress =~ "$ingress",
          exported_namespace =~ "$exported_namespace"
        }[$__rate_interval]
      )
    )
  ||| % $._config,

  local ingressResponseErrorRateGraphPanel =
    graphPanel.new(
      'Response error rate',
      datasource='$datasource',
      format='percentunit',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressResponseErrorRateQuery,
        legendFormat='{{ path }} - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressUpstreamTimeConsumedQuery = |||
    sum by (path, ingress, exported_namespace) (
      rate(
        nginx_ingress_controller_response_duration_seconds_sum{
          ingress =~ "$ingress",
          exported_namespace =~ "$exported_namespace"
        }[$__rate_interval]
      )
    )
  ||| % $._config,

  local ingressUpstreamTimeConsumedGraphPanel =
    graphPanel.new(
      'Upstream time consumed',
      datasource='$datasource',
      format='s',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressUpstreamTimeConsumedQuery,
        legendFormat='{{ path }} - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressErrorVolumeByPathQuery = |||
    sum (
      rate(
        nginx_ingress_controller_request_duration_seconds_count{
          ingress=~"$ingress",
          exported_namespace=~"$exported_namespace",
          status=~"[$error_codes].*"
        }[$__rate_interval]
      )
    ) by(path, ingress, exported_namespace, status)
  ||| % $._config,

  local ingressErrorVolumeByPathGraphPanel =
    graphPanel.new(
      'Response error volume',
      datasource='$datasource',
      format='reqps',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressErrorVolumeByPathQuery,
        legendFormat='{{ status }} {{ path }} - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressResponseSizeByPathQuery = |||
    sum (
      rate (
          nginx_ingress_controller_response_size_sum {
            ingress=~"$ingress",
            exported_namespace=~"$exported_namespace",
          }[$__rate_interval]
      )
    )  by (path, ingress, exported_namespace)
    /
    sum (
      rate(
        nginx_ingress_controller_response_size_count {
            ingress=~"$ingress",
            exported_namespace=~"$exported_namespace",
        }[$__rate_interval]
      )
    ) by (path, ingress, exported_namespace)
  ||| % $._config,

  local ingressResponseSizeByPathGraphPanel =
    graphPanel.new(
      'Average response size',
      datasource='$datasource',
      format='decbytes',
      legend_show=true,
      legend_values=true,
      legend_alignAsTable=true,
      legend_rightSide=true,
      legend_avg=true,
      legend_max=true,
      legend_hideZero=true,
    )
    .addTarget(
      prometheus.target(
        ingressResponseSizeByPathQuery,
        legendFormat='{{ path }} - {{ ingress }}/{{ exported_namespace }}',
      )
    ),

  local ingressResponseTimeRow =
    row.new(
      title='Ingress Response Times'
    ),

  local ingressPathRow =
    row.new(
      title='Ingress Paths'
    ),

  'ingress-nginx-request-handling-performance.json':
    // Core dashboard
    dashboard.new(
      'Ingress Nginx / Request Handling Performance',
      description='A dashboard that monitors Ingress-nginx. It is created using the (Ingress-Nginx-mixin)[https://github.com/adinhodovic/ingress-nginx-mixin]',
      uid=$._config.requestHandlingPerformanceDashboardUid,
      tags=$._config.tags,
      time_from='now-1h',
      time_to='now',
      editable='true',
      timezone='utc'
    )
    .addPanel(ingressResponseTimeRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
    .addPanel(ingressRequestHandlingTimeGraphPanel, gridPos={ h: 6, w: 12, x: 0, y: 1 })
    .addPanel(ingressUpstreamResponseTimeGraphPanel, gridPos={ h: 6, w: 12, x: 12, y: 1 })
    .addPanel(ingressPathRow, gridPos={ h: 1, w: 24, x: 0, y: 7 })
    .addPanel(ingressRequestVolumeByPathGraphPanel, gridPos={ h: 6, w: 12, x: 0, y: 8 })
    .addPanel(ingressUpstreamMedianResponseTimeGraphPanel, gridPos={ h: 6, w: 12, x: 12, y: 8 })
    .addPanel(ingressResponseErrorRateGraphPanel, gridPos={ h: 6, w: 12, x: 0, y: 14 })
    .addPanel(ingressUpstreamTimeConsumedGraphPanel, gridPos={ h: 6, w: 12, x: 12, y: 14 })
    .addPanel(ingressErrorVolumeByPathGraphPanel, gridPos={ h: 6, w: 12, x: 0, y: 20 })
    .addPanel(ingressResponseSizeByPathGraphPanel, gridPos={ h: 6, w: 12, x: 12, y: 20 })
    + { templating+: { list+: requestHandlingPerformanceDashboardTemplates } },
}
