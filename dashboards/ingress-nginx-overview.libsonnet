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

    local jobVariable =
      query.new(
        'job',
        'label_values(nginx_ingress_controller_config_hash{}, job)'
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Job') +
      query.selectionOptions.withMulti(false) +
      query.selectionOptions.withIncludeAll(false) +
      query.refresh.onLoad() +
      query.refresh.onTime(),

    local namespaceVariable =
      query.new(
        'namespace',
        'label_values(nginx_ingress_controller_config_hash{job="$job"}, controller_namespace)',
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
              job="$job",
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
              job="$job",
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
              job="$job",
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
              job="$job",
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
    local ingressRequestVolumeTimeSeriesPanel =
      timeSeriesPanel.new(
        'Ingress Request Volume',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressRequestQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ ingress }}/{{ exported_namespace }}'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('reqps') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true),

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
      timeSeriesPanel.new(
        'Ingress Success Rate (non $error_codes-xx responses)',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressSuccessRateQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ ingress }}/{{ exported_namespace }}'
          ),
        ]
      ) +
      tsStandardOptions.withUnit('percentunit') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

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
    |||,
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
      tablePanel.new(
        'Ingress Percentile Response Times and Transfer Rates',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('P50 Latency') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('dtdurations') +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingress50thPercentileResponseQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            ingress90thPercentileResponseQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            ingress99thPercentileResponseQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            ingressRequestSizeQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
          prometheus.new(
            '$datasource',
            ingressResponseSizeQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
        ]
      ) +
      tbQueryOptions.withTransformations([
        tbQueryOptions.transformation.withId(
          'merge'
        ),
        tbQueryOptions.transformation.withId(
          'organize'
        ) +
        tbQueryOptions.transformation.withOptions(
          {
            renameByName: {
              job: 'Job',
              exported_namespace: 'Namespace',
              ingress: 'Ingress',
              'Value #A': 'P50 Latency',
              'Value #B': 'P95 Latency',
              'Value #C': 'P99 Latency',
              'Value #D': 'IN',
              'Value #E': 'OUT',
            },
            indexByName: {
              namespace: 0,
              job: 1,
              ingress: 2,
              'Value #A': 3,
              'Value #B': 4,
              'Value #C': 5,
              'Value #D': 6,
              'Value #E': 7,  // TODO(adinhodovic): unit: BPS
            },
            excludeByName: {
              Time: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('Ingress') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To Ingress') +  // todo: Fix job
            tbPanelOptions.link.withType('dashboard') +
            tbPanelOptions.link.withUrl(
              '/d/%s/ingress-nginx-overview?var-exported_namespace=${__data.fields.Namespace}&var-job=${__data.fields.Job}&var-ingress=${__data.fields.Ingress}' % $._config.requestsByViewDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local certificateExpiryQuery = |||
      avg(nginx_ingress_controller_ssl_expire_time_seconds{pod=~"$controller"}) by (host) - time()
    ||| % $._config,

    local certificateTable =
      tablePanel.new(
        'Ingress Certificate Expiry',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('TTL') +
        tbOptions.sortBy.withDesc(true)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('dtdurations') +
      tbQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            certificateExpiryQuery,
          ) +
          prometheus.withFormat('table') +
          prometheus.withInstant(true),
        ]
      ) +
      tbQueryOptions.withTransformations([
        tbQueryOptions.transformation.withId(
          'merge'
        ),
        tbQueryOptions.transformation.withId(
          'organize'
        ) +
        tbQueryOptions.transformation.withOptions(
          {
            renameByName: {
              host: 'Host',
              'Value #A': 'TTL',
            },
            indexByName: {
              host: 0,
              'Value #A': 1,
              // alias: 'TTL',
              // pattern: 'Value',
              // type: 'number',
              // unit: 's',
              // decimals: '0',
              // colorMode: 'cell',
              // colors: [
              //   'null',
              //   'red',
              //   'green',
              // ],
              // thresholds: [
              //   0,
              //   1814400,
              // ],
            },
            excludeByName: {
              Time: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('Ingress') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To Site') +  // todo: Fix job
            tbPanelOptions.link.withType('link') +
            tbPanelOptions.link.withUrl(
              '${__data.fields.Host}'
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
      ]),

    local controllerRow =
      row.new(
        title='Controller'
      ),

    local ingressRow =
      row.new(
        title='Ingress'
      ),

    local certificateRow =
      row.new(
        title='Certificates'
      ),

    'ingress-nginx-overview.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Ingress Nginx / Overview',
      ) +
      dashboard.withDescription('A dashboard that monitors Ingress-nginx. It is created using the (Ingress-Nginx-mixin)[https://github.com/adinhodovic/ingress-nginx-mixin]') +
      dashboard.withUid($._config.overviewDashboardUid) +
      dashboard.withTags($._config.tags) +
      dashboard.withTimezone('utc') +
      dashboard.withEditable(true) +
      dashboard.time.withFrom('now-1h') +
      dashboard.time.withTo('now') +
      dashboard.withVariables(variables) +
      dashboard.withLinks(
        [
          dashboard.link.dashboards.new('Ingress Nginx Dashboards', $._config.tags) +
          dashboard.link.link.options.withTargetBlank(true),
        ]
      ) +
      dashboard.withPanels(
        [
          controllerRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [controllerRequestVolumeStatPanel, controllerConnectionsStatPanel, controllerSuccessRateStatPanel],
          panelWidth=6,
          panelHeight=4,
          startY=1
        ) +
        grid.makeGrid(
          [controllerConfigReloadsStatPanel, controllerConfigLastStatusStatPanel],
          panelWidth=3,
          panelHeight=4,
          startY=18
        ) +
        [
          ingressRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [ingressRequestVolumeGraphPanel, ingressSuccessRateGraphPanel],
          panelWidth=12,
          panelHeight=8,
          startY=6
        ) +
        [
          ingressResponseTable +
          table.gridPos.withX(0) +
          table.gridPos.withY(14) +
          table.gridPos.withW(24) +
          table.gridPos.withH(8),
          certificateRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(22) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          certificateTable +
          table.gridPos.withX(0) +
          table.gridPos.withY(23) +
          table.gridPos.withW(24) +
          table.gridPos.withH(8),
        ] +

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
