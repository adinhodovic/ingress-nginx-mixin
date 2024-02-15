local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local statPanel = g.panel.stat;
local tablePanel = g.panel.table;
local timeSeriesPanel = g.panel.timeSeries;

local variable = dashboard.variable;
local datasource = variable.datasource;
local prometheus = g.query.prometheus;
local query = variable.query;
local custom = variable.custom;

// Stat
local stOptions = statPanel.options;
local stStandardOptions = statPanel.standardOptions;
local stQueryOptions = statPanel.queryOptions;

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
local tbFieldConfig = tablePanel.fieldConfig;
local tbPanelOptions = tablePanel.panelOptions;
local tbOverride = tbStandardOptions.override;

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
        'label_values(nginx_ingress_controller_config_hash{job="$job", controller_namespace=~"$namespace"}, controller_class)'
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
        'label_values(nginx_ingress_controller_config_hash{job="$job", controller_namespace=~"$namespace", controller_class=~"$controller_class"}, controller_pod)'
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
        'label_values(nginx_ingress_controller_requests{job="$job", namespace=~"$namespace", controller_class=~"$controller_class", controller_pod=~"$controller"}, exported_namespace)'
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
        'label_values(nginx_ingress_controller_requests{job="$job", namespace=~"$namespace", controller_class=~"$controller_class", controller_pod=~"$controller", exported_namespace=~"$exported_namespace"}, ingress)'
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
      custom.generalOptions.withLabel('Error Codes') +
      custom.generalOptions.withDescription('4 represents all 4xx codes, 5 represents all 5xx codes') +
      custom.generalOptions.withCurrent('All', '$__all') +
      custom.selectionOptions.withMulti(true) +
      custom.selectionOptions.withIncludeAll(true, '4-5'),

    local variables = [
      datasourceVariable,
      jobVariable,
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
              job=~"$job",
              namespace=~"$namespace",
              controller_pod=~"$controller",
              controller_class=~"$controller_class"
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
            job=~"$job",
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
      stStandardOptions.withUnit('short') +
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
            job=~"$job",
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
            job=~"$job",
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
            job=~"$job",
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
          job=~"$job",
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
              job=~"$job",
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
      tsLegend.withSortDesc(true) +
      tsCustom.stacking.withMode('value') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local ingressSuccessRateQuery = |||
      sum(
        rate(
          nginx_ingress_controller_requests{
            job=~"$job",
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
            job=~"$job",
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            namespace=~"$namespace",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress"
          }[$__rate_interval]
        )
      ) by (ingress, exported_namespace)
    ||| % $._config,
    local ingressSuccessRateTimeSeriesPanel =
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
              job=~"$job",
              ingress!="",
              controller_pod=~"$controller",
              controller_class=~"$controller_class",
              controller_namespace=~"$namespace",
              exported_namespace=~"$exported_namespace",
              ingress=~"$ingress"
            }[$__rate_interval]
          )
        ) by (le, job, ingress, exported_namespace)
      )
    |||,
    local ingress90thPercentileResponseQuery = std.strReplace(ingress50thPercentileResponseQuery, '0.50', '0.90'),
    local ingress99thPercentileResponseQuery = std.strReplace(ingress50thPercentileResponseQuery, '0.50', '0.99'),

    // Request size queries
    local ingressRequestSizeQuery = |||
      sum(
        irate(
          nginx_ingress_controller_request_size_sum{
            job=~"$job",
            ingress!="",
            controller_pod=~"$controller",
            controller_class=~"$controller_class",
            controller_namespace=~"$namespace",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress"
          }[$__rate_interval]
        )
      ) by (job, ingress, exported_namespace)
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
              exported_namespace: 0,
              ingress: 1,
              'Value #A': 2,
              'Value #B': 3,
              'Value #C': 4,
              'Value #D': 5,
              'Value #E': 6,
            },
            excludeByName: {
              job: true,
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
              '/d/%s/ingress-nginx-overview?var-exported_namespace=${__data.fields.Namespace}&var-ingress=${__data.fields.Ingress}'
              % $._config.requestHandlingPerformanceDashboardUid
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
        tbOverride.byName.new('IN') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('binBps')
        ),
        tbOverride.byName.new('OUT') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withUnit('binBps')
        ),
      ]),

    local certificateExpiryQuery = |||
      avg(
        nginx_ingress_controller_ssl_expire_time_seconds{
          job=~"$job",
          pod=~"$controller"
        }
      ) by (host) - time()
    ||| % $._config,

    local certificateTable =
      tablePanel.new(
        'Ingress Certificate Expiry',
      ) +
      tbOptions.withSortBy(
        tbOptions.sortBy.withDisplayName('TTL') +
        tbOptions.sortBy.withDesc(false)
      ) +
      tbOptions.footer.TableFooterOptions.withEnablePagination(true) +
      tbStandardOptions.withUnit('s') +
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
          'organize'
        ) +
        tbQueryOptions.transformation.withOptions(
          {
            renameByName: {
              host: 'Host',
              Value: 'TTL',
            },
            indexByName: {
              host: 0,
              Value: 1,
            },
            excludeByName: {
              Time: true,
            },
          }
        ),
      ]) +
      tbStandardOptions.withOverrides([
        tbOverride.byName.new('Host') +
        tbOverride.byName.withPropertiesFromOptions(
          tbStandardOptions.withLinks(
            tbPanelOptions.link.withTitle('Go To Site') +  // todo: Fix job
            tbPanelOptions.link.withType('link') +
            tbPanelOptions.link.withUrl(
              'https://${__data.fields.Host}'
            ) +
            tbPanelOptions.link.withTargetBlank(true)
          )
        ),
        tbOverride.byName.new('TTL') +
        tbOverride.byName.withPropertiesFromOptions(
          tbFieldConfig.defaults.custom.withCellOptions(
            { type: 'color-text' }  // TODO(adinhodovic): Use jsonnet lib
          ) +
          tbStandardOptions.thresholds.withMode('absolute') +
          tbStandardOptions.thresholds.withSteps([
            tbStandardOptions.threshold.step.withValue(0) +
            tbStandardOptions.threshold.step.withColor('red'),
            tbStandardOptions.threshold.step.withValue(1814400) +
            tbStandardOptions.threshold.step.withColor('green'),
          ]),
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
        [
          controllerConfigReloadsStatPanel +
          row.gridPos.withX(18) +
          row.gridPos.withY(1) +
          row.gridPos.withW(3) +
          row.gridPos.withH(4),
          controllerConfigLastStatusStatPanel +
          row.gridPos.withX(21) +
          row.gridPos.withY(1) +
          row.gridPos.withW(3) +
          row.gridPos.withH(4),
          ingressRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(5) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [ingressRequestVolumeTimeSeriesPanel, ingressSuccessRateTimeSeriesPanel],
          panelWidth=12,
          panelHeight=8,
          startY=6
        ) +
        [
          ingressResponseTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(14) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(10),
          certificateRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(24) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
          certificateTable +
          tablePanel.gridPos.withX(0) +
          tablePanel.gridPos.withY(25) +
          tablePanel.gridPos.withW(24) +
          tablePanel.gridPos.withH(10),
        ],
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
