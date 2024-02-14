local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local pieChartPanel = g.panel.pieChart;
local tablePanel = g.panel.table;
local timeSeriesPanel = g.panel.timeSeries;
local heatmapPanel = g.panel.heatmap;

local variable = dashboard.variable;
local datasource = variable.datasource;
local query = variable.query;
local prometheus = g.query.prometheus;
local query = variable.query;
local custom = variable.custom;

// Stat
local stOptions = statPanel.options;
local stStandardOptions = statPanel.standardOptions;
local stQueryOptions = statPanel.queryOptions;

// Pie Chart
local pcOptions = pieChartPanel.options;
local pcStandardOptions = pieChartPanel.standardOptions;
local pcOverride = pcStandardOptions.override;
local pcLegend = pcOptions.legend;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

// Table
local tbOptions = tablePanel.options;
local tbStandardOptions = tablePanel.standardOptions;
local tbQueryOptions = tablePanel.queryOptions;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

// HeatmapPanel
local hmStandardOptions = heatmapPanel.standardOptions;
local hmQueryOptions = heatmapPanel.queryOptions;

{
  grafanaDashboards+:: {

    local datasourceVariable =
      datasource.new(
        'datasource',
        'prometheus',
      ) +
      datasource.generalOptions.withLabel('Data source'),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(nginx_ingress_controller_config_hash, controller_namespace)',
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Controller Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local controllerClassVariable =
      query.new(
        'controller_class',
        |||
          label_values(
            nginx_ingress_controller_config_hash{
              controller_namespace=~"$namespace"
            },
            controller_class
          )
        |||
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Controller Class') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),


    local controllerVariable =
      query.new(
        'controller',
        |||
          label_values(
            nginx_ingress_controller_config_hash{
              controller_namespace=~"$namespace",
              controller_class=~"$controller_class"
            },
            controller_pod
          )
        |||
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Controller') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local ingressExportedNamespaceVariable =
      query.new(
        'exported_namespace',
        |||
          label_values(
            nginx_ingress_controller_requests{
              namespace=~"$namespace",
              controller_class=~"$controller_class",
              controller_pod=~"$controller"
            },
            exported_namespace
          )
        |||
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Ingress Namespace') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local ingressVariable =
      query.new(
        'ingress',
        |||
          label_values(
            nginx_ingress_controller_requests{
              namespace=~"$namespace",
              controller_class=~"$controller_class",
              controller_pod=~"$controller",
              exported_namespace=~"$exported_namespace"
            },
            ingress
          )
        |||
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Ingress') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local errorCodesVariable =
      custom.new(
        'error_codes',
        values=['4', '5'],
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Error Codes') +
      query.generalOptions.withDescription('4 represents all 4xx codes, 5 represents all 5xx codes') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(true, '4-5') +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local overviewDashboardTemplates = [
      datasourceVariable,
      namespaceVariable,
      controllerClassVariable,
      controllerVariable,
      ingressExportedNamespaceVariable,
      ingressVariable,
      errorCodesVariable,
    ],

    local controllerRow =
      row.new(
        title='Controller'
      ),

    local controllerRequestVolumeQuery = |||
      round(
        sum(
          irate(
            nginx_ingress_controller_requests{
              controller_pod=~"$controller",
              controller_class=~"$controller_class",
              namespace=~"$namespace"
            }[$__rate_interval]
          )
        ), 0.001
      )
    |||,
    local controllerRequestVolumeStatPanel =
      statPanel.new(
        'Controller Request Volume',
      ) +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          controllerRequestVolumeQuery,
        )
      ) +
      stStandardOptions.withUnit('reqps') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.001) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local controllerConnectionsQuery = |||
      sum(
        avg_over_time(
          nginx_ingress_controller_nginx_process_connections{
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            controller_namespace=~"$namespace"
          }[$__rate_interval]
        )
      )
    |||,
    local controllerConnectionsStatPanel =
      statPanel.new(
        'Controller Connections',
      ) +
      statPanel.queryOptions.withTargets(
        prometheus.new(
          '$datasource',
          controllerConnectionsQuery,
        )
      ) +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.1) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),


    local controllerSuccessRateQuery = |||
      sum(
        rate(
          nginx_ingress_controller_requests{
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            namespace=~"$namespace",
            exported_namespace=~"$exported_namespace",
            status!~"[$error_codes].*"
          }[$__rate_interval]
        )
      )
      /
      sum(
        rate(
          nginx_ingress_controller_requests{
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            exported_namespace=~"$exported_namespace",
            namespace=~"$namespace"
          }[$__rate_interval]
        )
      )
    |||,
    local controllerSuccessRateStatPanel =
      statPanel.new(
        'Controller Success Rate (non $error_codes-xx responses)',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          controllerSuccessRateQuery,
        )
      ) +
      stStandardOptions.withUnit('percentunit') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('red'),
        stStandardOptions.threshold.step.withValue(0.95) +
        stStandardOptions.threshold.step.withColor('yellow'),
        stStandardOptions.threshold.step.withValue(0.99) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local controllerConfigReloadsQuery = |||
      avg(
        irate(
          nginx_ingress_controller_success{
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            controller_namespace=~"$namespace"
          }[$__rate_interval]
        )
      ) * 60
    ||| % $._config,
    local controllerConfigReloadsStatPanel =
      statPanel.new(
        'Config Reloads',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          controllerConfigReloadsQuery,
        )
      ) +
      stStandardOptions.withUnit('short') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0.0) +
        stStandardOptions.threshold.step.withColor('green'),
      ]),

    local controllerConfigLastStatusQuery = |||
      count(
        nginx_ingress_controller_config_last_reload_successful{
          controller_pod=~"$controller",
          controller_namespace=~"$namespace"
        } == 0
      ) OR vector(0)
    ||| % $._config,
    local controllerConfigLastStatusStatPanel =
      statPanel.new(
        'Last Config Failed',
      ) +
      stQueryOptions.withTargets(
        prometheus.new(
          '$datasource',
          controllerConfigLastStatusQuery,
        )
      ) +
      stStandardOptions.withUnit('bool') +
      stOptions.reduceOptions.withCalcs(['lastNotNull']) +
      stStandardOptions.thresholds.withSteps([
        stStandardOptions.threshold.step.withValue(0) +
        stStandardOptions.threshold.step.withColor('green'),
        stStandardOptions.threshold.step.withValue(1) +
        stStandardOptions.threshold.step.withColor('red'),
      ]),

    local ingressRow =
      row.new(
        title='Ingress'
      ),

    local ingressRequestQuery = |||
      round(
        sum(
          irate(
            nginx_ingress_controller_requests{
              controller_pod=~"$controller",
              controller_class=~"$controller_class",
              controller_namespace=~"$namespace",
              ingress=~"$ingress",
              exported_namespace=~"$exported_namespace"
            }[$__rate_interval]
          )
        ) by (ingress, exported_namespace), 0.001
      )
    ||| % $._config,
    local ingressRequestVolumeGraphPanel =
      graphPanel.new(
        'Ingress Request Volume',
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
          ingressRequestQuery,
          legendFormat='{{ ingress }}/{{ exported_namespace }}',
        )
      ),

    local ingressSuccessRateQuery = |||
      sum(
        rate(
          nginx_ingress_controller_requests{
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            namespace=~"$namespace",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress",
            status!~"[$error_codes].*"
          }[$__rate_interval]
        )
      ) by (ingress, exported_namespace)
      /
      sum(
        rate(
          nginx_ingress_controller_requests{
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            namespace=~"$namespace",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress"
          }[$__rate_interval]
        )
      ) by (ingress, exported_namespace)
    ||| % $._config,
    local ingressSuccessRateGraphPanel =
      graphPanel.new(
        'Ingress Success Rate (non $error_codes-xx responses)',
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
          legendFormat='{{ ingress }}/{{ exported_namespace }}',
        )
      ),

    // Table
    // Percentile queries
    local ingress50thPercentileResponseQuery = |||
      histogram_quantile(
        0.50, sum(
          rate(
            nginx_ingress_controller_request_duration_seconds_bucket{
              ingress!="",
              controller_pod=~"$controller",
              controller_class=~"$controller_class",
              controller_namespace=~"$namespace",
              exported_namespace=~"$exported_namespace",
              ingress=~"$ingress"
            }[$__rate_interval]
          )
        ) by (le, ingress, exported_namespace)
      )
    ||| % $._config,
    local ingress90thPercentileResponseQuery = std.strReplace(ingress50thPercentileResponseQuery, '0.50', '0.90'),
    local ingress99thPercentileResponseQuery = std.strReplace(ingress50thPercentileResponseQuery, '0.50', '0.99'),

    // Request size queries
    local ingressRequestSizeQuery = |||
      sum(
        irate(
          nginx_ingress_controller_request_size_sum{
            ingress!="",
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            controller_namespace=~"$namespace",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress"
          }[$__rate_interval]
        )
      ) by (ingress, exported_namespace)
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
            alias: 'Namespace',
            pattern: 'exported_namespace',
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
      avg(nginx_ingress_controller_ssl_expire_time_seconds{pod=~"$controller"}) by (host) - time()
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
        tags=$._config.tags,
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
      + { templating+: { list+: overviewDashboardTemplates } },


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

    local ingressResponseTimeRow =
      row.new(
        title='Ingress Response Times'
      ),

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

    local ingressPathRow =
      row.new(
        title='Ingress Paths'
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
  },
}
