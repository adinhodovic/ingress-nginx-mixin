local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;

{
  grafanaDashboards+:: {

    local prometheusTemplate =
      template.datasource(
        'datasource',
        'prometheus',
        'Prometheus',
        hide='',
      ),

    local namespaceTemplate =
      template.new(
        name='namespace',
        label='Controller Namespace',
        datasource='$datasource',
        query='label_values(nginx_ingress_controller_config_hash, controller_namespace)',
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local controllerClassTemplate =
      template.new(
        name='controller_class',
        label='Controller Class',
        datasource='$datasource',
        query='label_values(nginx_ingress_controller_config_hash{namespace=~"$namespace"}, controller_class)',
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local controllerTemplate =
      template.new(
        name='controller',
        label='Controller',
        datasource='$datasource',
        query='label_values(nginx_ingress_controller_config_hash{namespace=~"$namespace",controller_class=~"$controller_class"}, controller_pod)',
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local ingressExportedNamespaceTemplate =
      template.new(
        name='exported_namespace',
        label='Ingress Namespace',
        datasource='$datasource',
        query='label_values(nginx_ingress_controller_requests{namespace=~"$namespace",controller_class=~"$controller_class",controller_pod=~"$controller"}, exported_namespace)',
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local ingressTemplate =
      template.new(
        name='ingress',
        label='Ingress',
        datasource='$datasource',
        query='label_values(nginx_ingress_controller_requests{namespace=~"$namespace",controller_class=~"$controller_class",controller_pod=~"$controller", exported_namespace=~"$exported_namespace"}, ingress)',
        current='',
        hide='',
        refresh=1,
        multi=true,
        includeAll=true,
        sort=1
      ),

    local templates = [
      prometheusTemplate,
      namespaceTemplate,
      controllerClassTemplate,
      controllerTemplate,
      ingressExportedNamespaceTemplate,
      ingressTemplate,
    ],

    local controllerRow =
      row.new(
        title='Controller'
      ),

    local controllerRequestVolumeQuery = |||
      round(sum(irate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace"}[2m])), 0.001)
    ||| % $._config,
    local controllerRequestVolumeStatPanel =
      statPanel.new(
        'Controller Request Volume',
        datasource='$datasource',
        unit='ops',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerRequestVolumeQuery))
      .addThresholds([
        { color: 'red', value: 0 },
        { color: 'green', value: 1 },
      ]),

    local controllerConnectionsQuery = |||
      sum(avg_over_time(nginx_ingress_controller_nginx_process_connections{controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace"}[2m]))
    ||| % $._config,
    local controllerConnectionsStatPanel =
      statPanel.new(
        'Controller Connections',
        datasource='$datasource',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerConnectionsQuery))
      .addThresholds([
        { color: 'red', value: 0 },
        { color: 'green', value: 1 },
      ]),


    local controllerSuccessRateQuery = |||
      sum(rate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace",status!~"[4-5].*"}[2m])) / sum(rate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace"}[2m]))
    ||| % $._config,
    local controllerSuccessRateStatPanel =
      statPanel.new(
        'Controller Success Rate (non-4|5xx responses)',
        datasource='$datasource',
        unit='percentunit',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerSuccessRateQuery))
      .addThresholds([
        { color: 'red', value: 0.90 },
        { color: 'yellow', value: 0.95 },
        { color: 'green', value: 0.99 },
      ]),

    local controllerConfigReloadsQuery = |||
      avg(irate(nginx_ingress_controller_success{controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace"}[1m])) * 60
    ||| % $._config,
    local controllerConfigReloadsStatPanel =
      statPanel.new(
        'Config Reloads',
        datasource='$datasource',
        unit='short',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerConfigReloadsQuery))
      .addThresholds([
        { color: 'green', value: 0 },
      ]),

    local controllerConfigLastStatusQuery = |||
      count(nginx_ingress_controller_config_last_reload_successful{controller_pod=~"$controller",controller_namespace=~"$namespace"} == 0) OR vector(0)
    ||| % $._config,
    local controllerConfigLastStatusStatPanel =
      statPanel.new(
        'Last Config Failed',
        unit='bool',
        datasource='$datasource',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerConfigLastStatusQuery))
      .addThresholds([
        { color: 'green', value: 0 },
        { color: 'red', value: 1 },
      ]),

    local ingressRow =
      row.new(
        title='Ingress'
      ),

    local ingressRequestQuery = |||
      round(sum(irate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace",ingress=~"$ingress", exported_namespace=~"$exported_namespace"}[2m])) by (ingress), 0.001)
    ||| % $._config,
    local ingressRequestVolumeGraphPanel =
      graphPanel.new(
        'Ingress Request Volume',
        datasource='$datasource',
        format='ops',
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
          ingressRequestQuery,
          legendFormat='{{ ingress }}',
        )
      ),

    local ingressSuccessRateQuery = |||
      sum(rate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace",ingress=~"$ingress",exported_namespace=~"$exported_namespace", status!~"[4-5].*"}[2m])) by (ingress) / sum(rate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace",ingress=~"$ingress", exported_namespace=~"$exported_namespace"}[2m])) by (ingress)
    ||| % $._config,
    local ingressSuccessRateGraphPanel =
      graphPanel.new(
        'Ingress Success Rate (non-4|5xx responses)',
        datasource='$datasource',
        format='percentunit',
        fill='0',
        linewidth='3',
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
          ingressSuccessRateQuery,
          legendFormat='{{ ingress }}',
        )
      ),

    // Table
    // Percentile queries
    local ingress50thPercentileResponseQuery = |||
      histogram_quantile(0.50, sum(rate(nginx_ingress_controller_request_duration_seconds_bucket{ingress!="",controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace", exported_namespace=~"$exported_namespace", ingress=~"$ingress"}[2m])) by (le, ingress))
    ||| % $._config,
    local ingress90thPercentileResponseQuery = std.strReplace(ingress50thPercentileResponseQuery, '0.50', '0.90'),
    local ingress99thPercentileResponseQuery = std.strReplace(ingress50thPercentileResponseQuery, '0.50', '0.99'),

    // Request size queries
    local ingressRequestSizeQuery = |||
      sum(irate(nginx_ingress_controller_request_size_sum{ingress!="",controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace",ingress=~"$ingress"}[2m])) by (ingress)
    |||,
    local ingressResponseSizeQuery = std.strReplace(ingressRequestSizeQuery, 'request', 'response'),

    local ingressResponseTable =
      grafana.tablePanel.new(
        'Ingress Percentile Response Times and Transfer Rates',
        datasource='$datasource',
        sort={
          col: 1,
          desc: false,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Ingress',
            pattern: 'ingress',
          },
          {
            alias: 'P50 Latency',
            pattern: 'Value #A',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'P90 Latency',
            pattern: 'Value #B',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'P99 Latency',
            pattern: 'Value #C',
            type: 'number',
            unit: 'dtdurations',
          },
          {
            alias: 'IN',
            pattern: 'Value #D',
            type: 'number',
            unit: 'Bps',
            decimals: '0',
          },
          {
            alias: 'OUT',
            pattern: 'Value #E',
            type: 'number',
            unit: 'Bps',
            decimals: '0',
          },
        ]
      )
      .addTarget(prometheus.target(ingress50thPercentileResponseQuery, format='table', instant=true))
      .addTarget(prometheus.target(ingress90thPercentileResponseQuery, format='table', instant=true))
      .addTarget(prometheus.target(ingress99thPercentileResponseQuery, format='table', instant=true))
      .addTarget(prometheus.target(ingressRequestSizeQuery, format='table', instant=true))
      .addTarget(prometheus.target(ingressResponseSizeQuery, format='table', instant=true)),


    local certificateRow =
      row.new(
        title='Certificates'
      ),

    local certificateExpiryQuery = |||
      avg(nginx_ingress_controller_ssl_expire_time_seconds{pod=~"$controller", namespace=~"$namespace", host!="_"}) by (host) - time()
    ||| % $._config,
    local certificateTable =
      grafana.tablePanel.new(
        'Ingress Certificate Expiry',
        datasource='$datasource',
        sort={
          col: 2,
          desc: false,
        },
        styles=[
          {
            alias: 'Time',
            dateFormat: 'YYYY-MM-DD HH:mm:ss',
            type: 'hidden',
            pattern: 'Time',
          },
          {
            alias: 'Host',
            pattern: 'host',
          },
          {
            alias: 'TTL',
            pattern: 'Value',
            type: 'number',
            unit: 's',
            decimals: '0',
            colorMode: 'cell',
            colors: [
              'null',
              'red',
              'green',
            ],
            thresholds: [
              0,
              1814400,
            ],
          },
        ]
      )
      .addTarget(prometheus.target(certificateExpiryQuery, format='table', instant=true)),

    'ingress-nginx-overview.json':
      // Core dashboard
      dashboard.new(
        'Ingress Nginx / Overview',
        description='A dashboard that monitors Ingress-nginx. It is created using the (Ingress-Nginx-mixin)[https://github.com/adinhodovic/ingress-nginx-mixin]',
        uid=$._config.overviewDashboardUid,
        time_from='now-1h',
        time_to='now',
        editable='true',
        timezone='utc'
      )
      .addPanel(controllerRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(controllerRequestVolumeStatPanel, gridPos={ h: 4, w: 6, x: 0, y: 1 })
      .addPanel(controllerConnectionsStatPanel, gridPos={ h: 4, w: 6, x: 6, y: 1 })
      .addPanel(controllerSuccessRateStatPanel, gridPos={ h: 4, w: 6, x: 12, y: 1 })
      .addPanel(controllerConfigReloadsStatPanel, gridPos={ h: 4, w: 3, x: 18, y: 1 })
      .addPanel(controllerConfigLastStatusStatPanel, gridPos={ h: 4, w: 3, x: 21, y: 1 })
      .addPanel(ingressRow, gridPos={ h: 1, w: 24, x: 0, y: 5 })
      .addPanel(ingressRequestVolumeGraphPanel, gridPos={ h: 8, w: 12, x: 0, y: 6 })
      .addPanel(ingressSuccessRateGraphPanel, gridPos={ h: 8, w: 12, x: 12, y: 6 })
      .addPanel(ingressResponseTable, gridPos={ h: 8, w: 24, x: 0, y: 14 })
      .addPanel(certificateRow, gridPos={ h: 1, w: 24, x: 0, y: 22 })
      .addPanel(certificateTable, gridPos={ h: 8, w: 24, x: 0, y: 23 })
      + { templating+: { list+: templates } },
  },
}
