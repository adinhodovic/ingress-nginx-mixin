local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local dashboard = g.dashboard;
local row = g.panel.row;
local grid = g.util.grid;

local timeSeriesPanel = g.panel.timeSeries;

local variable = dashboard.variable;
local datasource = variable.datasource;
local prometheus = g.query.prometheus;
local query = variable.query;
local custom = variable.custom;

// Timeseries
local tsOptions = timeSeriesPanel.options;
local tsStandardOptions = timeSeriesPanel.standardOptions;
local tsQueryOptions = timeSeriesPanel.queryOptions;
local tsFieldConfig = timeSeriesPanel.fieldConfig;
local tsCustom = tsFieldConfig.defaults.custom;
local tsLegend = tsOptions.legend;

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

    local ingressExportedNamespaceVariable =
      query.new(
        'exported_namespace',
        'label_values(nginx_ingress_controller_requests{job="$job"}, exported_namespace)'
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
        'label_values(nginx_ingress_controller_requests{job="$job", exported_namespace=~"$exported_namespace"}, ingress)'
      ) +
      query.withDatasourceFromVariable(datasourceVariable) +
      query.withSort(1) +
      query.generalOptions.withLabel('Ingress') +
      query.selectionOptions.withMulti(true) +
      query.selectionOptions.withIncludeAll(false) +
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
      ingressExportedNamespaceVariable,
      ingressVariable,
      errorCodesVariable,
    ],

    local ingressRequestHandlingTimeQuery = |||
      histogram_quantile(
        0.5,
        sum by (le, ingress, exported_namespace)(
          rate(
            nginx_ingress_controller_request_duration_seconds_bucket{
              job=~"$job",
              exported_namespace=~"$exported_namespace",
              ingress =~ "$ingress"
            }[$__rate_interval]
          )
        )
      )
    ||| % $._config,

    local ingressRequestTimeTimeSeriesPanel =
      timeSeriesPanel.new(
        'Total Request Time',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressRequestHandlingTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '.5 - {{ ingress }}/{{ exported_namespace }}',
          ),
          prometheus.new(
            '$datasource',
            std.strReplace(ingressRequestHandlingTimeQuery, '0.5', '0.95'),
          ) +
          prometheus.withLegendFormat(
            '.95 - {{ ingress }}/{{ exported_namespace }}',
          ),
          prometheus.new(
            '$datasource',
            std.strReplace(ingressRequestHandlingTimeQuery, '0.5', '0.99'),
          ) +
          prometheus.withLegendFormat(
            '.99 - {{ ingress }}/{{ exported_namespace }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local ingressUpstreamResponseTimeQuery = |||
      histogram_quantile(
        0.5,
        sum by (le, ingress, exported_namespace)(
          rate(
            nginx_ingress_controller_response_duration_seconds_bucket{
              job=~"$job",
              exported_namespace=~"$exported_namespace",
              ingress =~ "$ingress"
            }[$__rate_interval]
          )
        )
      )
    ||| % $._config,

    local ingressUpstreamResponseTimeSeriesPanel =
      timeSeriesPanel.new(
        'Upstream Response Time',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressUpstreamResponseTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '.5 - {{ ingress }}/{{ exported_namespace }}',
          ),
          prometheus.new(
            '$datasource',
            std.strReplace(ingressUpstreamResponseTimeQuery, '0.5', '0.95'),
          ) +
          prometheus.withLegendFormat(
            '.95 - {{ ingress }}/{{ exported_namespace }}',
          ),
          prometheus.new(
            '$datasource',
            std.strReplace(ingressUpstreamResponseTimeQuery, '0.5', '0.99'),
          ) +
          prometheus.withLegendFormat(
            '.99 - {{ ingress }}/{{ exported_namespace }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local ingressRequestVolumeQuery = |||
      sum by (path, ingress, exported_namespace)(
        rate(
          nginx_ingress_controller_request_duration_seconds_count{
            job=~"$job",
            exported_namespace=~"$exported_namespace",
            ingress =~ "$ingress"
          }[$__rate_interval]
        )
      )
    ||| % $._config,

    local ingressRequestVolumeByPathTimeSeriesPanel =
      timeSeriesPanel.new(
        'Request Volume',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressRequestVolumeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ path }} - {{ ingress }}/{{ exported_namespace }}',
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

    local ingressUpstreamMedianResponseTimeQuery = |||
      histogram_quantile(
        .5,
        sum by (le, path, ingress, exported_namespace)(
          rate(
            nginx_ingress_controller_response_duration_seconds_bucket{
              job=~"$job",
              exported_namespace=~"$exported_namespace",
              ingress =~ "$ingress"
            }[$__rate_interval]
          )
        )
      )
    ||| % $._config,

    local ingressUpstreamMedianResponseTimeSeriesPanel =
      timeSeriesPanel.new(
        'Median upstream response time',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressUpstreamMedianResponseTimeQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ path }} - {{ ingress }}/{{ exported_namespace }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local ingressResponseErrorRateQuery = |||
      sum by (path, ingress, exported_namespace) (
        rate(
          nginx_ingress_controller_requests{
            job=~"$job",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress",
            status=~"[$error_codes].*"
          }[$__rate_interval]
        )
      )
      /
      sum by (path, ingress, exported_namespace) (
        rate(
          nginx_ingress_controller_requests{
            job=~"$job",
            exported_namespace =~ "$exported_namespace",
            ingress =~ "$ingress"
          }[$__rate_interval]
        )
      )
    ||| % $._config,

    local ingressResponseErrorRateTimeSeriesPanel =
      timeSeriesPanel.new(
        'Response error rate',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressResponseErrorRateQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ path }} - {{ ingress }}/{{ exported_namespace }}',
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
      tsCustom.stacking.withMode('value') +
      tsCustom.withFillOpacity(100) +
      tsCustom.withSpanNulls(false),

    local ingressUpstreamTimeConsumedQuery = |||
      sum by (path, ingress, exported_namespace) (
        rate(
          nginx_ingress_controller_response_duration_seconds_sum{
            job=~"$job",
            exported_namespace =~ "$exported_namespace",
            ingress =~ "$ingress"
          }[$__rate_interval]
        )
      )
    ||| % $._config,

    local ingressUpstreamTimeConsumedTimeSeriesPanel =
      timeSeriesPanel.new(
        'Upstream time consumed',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressUpstreamTimeConsumedQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ path }} - {{ ingress }}/{{ exported_namespace }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('s') +
      tsOptions.tooltip.withMode('multi') +
      tsOptions.tooltip.withSort('desc') +
      tsLegend.withShowLegend(true) +
      tsLegend.withDisplayMode('table') +
      tsLegend.withPlacement('right') +
      tsLegend.withCalcs(['mean', 'max']) +
      tsLegend.withSortBy('Mean') +
      tsLegend.withSortDesc(true) +
      tsCustom.withSpanNulls(false),

    local ingressErrorVolumeByPathQuery = |||
      sum (
        rate(
          nginx_ingress_controller_request_duration_seconds_count{
            job=~"$job",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress",
            status=~"[$error_codes].*"
          }[$__rate_interval]
        )
      ) by(path, ingress, exported_namespace, status)
    ||| % $._config,

    local ingressErrorVolumeByPathTimeSeriesPanel =
      timeSeriesPanel.new(
        'Response error volume',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressErrorVolumeByPathQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ status }} {{ path }} - {{ ingress }}/{{ exported_namespace }}',
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

    local ingressResponseSizeByPathQuery = |||
      sum (
        rate (
          nginx_ingress_controller_response_size_sum {
            job=~"$job",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress"
          }[$__rate_interval]
        )
      )  by (path, ingress, exported_namespace)
      /
      sum (
        rate(
          nginx_ingress_controller_response_size_count {
            job=~"$job",
            exported_namespace=~"$exported_namespace",
            ingress=~"$ingress",
          }[$__rate_interval]
        )
      ) by (path, ingress, exported_namespace)
    ||| % $._config,

    local ingressResponseSizeByPathTimeSeriesPanel =
      timeSeriesPanel.new(
        'Average response size',
      ) +
      tsQueryOptions.withTargets(
        [
          prometheus.new(
            '$datasource',
            ingressResponseSizeByPathQuery,
          ) +
          prometheus.withLegendFormat(
            '{{ path }} - {{ ingress }}/{{ exported_namespace }}',
          ),
        ]
      ) +
      tsStandardOptions.withUnit('decbytes') +
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

    local ingressResponseTimeRow =
      row.new(
        title='Ingress Response Times'
      ),

    local ingressPathRow =
      row.new(
        title='Ingress Paths'
      ),

    'ingress-nginx-request-handling-performance.json':
      $._config.bypassDashboardValidation +
      dashboard.new(
        'Ingress Nginx / Request Handling Performance',
      ) +
      dashboard.withDescription('A dashboard that monitors Ingress-nginx. It is created using the (Ingress-Nginx-mixin)[https://github.com/adinhodovic/ingress-nginx-mixin]') +
      dashboard.withUid($._config.requestHandlingPerformanceDashboardUid) +
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
          ingressResponseTimeRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(0) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [ingressRequestTimeTimeSeriesPanel, ingressUpstreamResponseTimeSeriesPanel],
          panelWidth=12,
          panelHeight=6,
          startY=1
        ) +
        [
          ingressPathRow +
          row.gridPos.withX(0) +
          row.gridPos.withY(7) +
          row.gridPos.withW(24) +
          row.gridPos.withH(1),
        ] +
        grid.makeGrid(
          [ingressRequestVolumeByPathTimeSeriesPanel, ingressUpstreamMedianResponseTimeSeriesPanel],
          panelWidth=12,
          panelHeight=6,
          startY=8
        ) +
        grid.makeGrid(
          [ingressResponseErrorRateTimeSeriesPanel, ingressUpstreamTimeConsumedTimeSeriesPanel],
          panelWidth=12,
          panelHeight=6,
          startY=14
        ) +
        grid.makeGrid(
          [ingressErrorVolumeByPathTimeSeriesPanel, ingressResponseSizeByPathTimeSeriesPanel],
          panelWidth=12,
          panelHeight=6,
          startY=20
        )
      ) +
      if $._config.annotation.enabled then
        dashboard.withAnnotations($._config.customAnnotation)
      else {},
  },
}
