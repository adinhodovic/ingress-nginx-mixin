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
        label='Namespace',
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
        label='Exported Namespace',
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
        query='label_values(nginx_ingress_controller_requests{namespace=~"$namespace",controller_class=~"$controller_class",controller=~"$controller", exported_namespace=~"$exported_namespace"}, ingress)',
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
      .addTarget(prometheus.target(controllerRequestVolumeQuery)),

    local controllerConnectionsQuery = |||
      sum(avg_over_time(nginx_ingress_controller_nginx_process_connections{controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace"}[2m]))
    ||| % $._config,
    local controllerConnectionsStatPanel =
      statPanel.new(
        'Controller Connections',
        datasource='$datasource',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerConnectionsQuery)),

    local controllerSuccessRateQuery = |||
      sum(rate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace", exported_namespace=~"$exported_namespace",status!~"[4-5].*"}[2m])) / sum(rate(nginx_ingress_controller_requests{controller_pod=~"$controller",controller_class=~"$controller_class",namespace=~"$namespace"}[2m]))
    ||| % $._config,
    local controllerSuccessRateStatPanel =
      statPanel.new(
        'Controller Success Rate (non-4|5xx responses)',
        datasource='$datasource',
        unit='percentunit',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerSuccessRateQuery)),

    local controllerConfigReloadsQuery = |||
      avg(irate(nginx_ingress_controller_success{controller_pod=~"$controller",controller_class=~"$controller_class",controller_namespace=~"$namespace"}[1m])) * 60
    ||| % $._config,
    local controllerConfigReloadsStatPanel =
      statPanel.new(
        'Config Reloads',
        datasource='$datasource',
        unit='percentunit',
        reducerFunction='lastNotNull',
      )
      .addTarget(prometheus.target(controllerConfigReloadsQuery)),

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
      .addTarget(prometheus.target(controllerConfigLastStatusQuery)),

    local ingressRow =
      row.new(
        title='Ingress'
      ),

    'ingress-nginx.json':
      // Core dashboard
      dashboard.new(
        'Ingress Nginx / Overview',
        description='A dashboard that monitors Ingress-nginx. It is created using the (Ingress-Nginx-mixin)[]',
        uid='ingress-nginx-mixin',
        time_from='now-1h',
        time_to='now',
        timezone='utc'
      )
      .addPanel(controllerRow, gridPos={ h: 1, w: 24, x: 0, y: 0 })
      .addPanel(controllerRequestVolumeStatPanel, gridPos={ h: 4, w: 6, x: 0, y: 1 })
      .addPanel(controllerConnectionsStatPanel, gridPos={ h: 4, w: 6, x: 6, y: 1 })
      .addPanel(controllerSuccessRateStatPanel, gridPos={ h: 4, w: 6, x: 12, y: 1 })
      .addPanel(controllerConfigReloadsStatPanel, gridPos={ h: 4, w: 3, x: 18, y: 1 })
      .addPanel(controllerConfigLastStatusStatPanel, gridPos={ h: 4, w: 3, x: 21, y: 1 })
      .addPanel(ingressRow, gridPos={ h: 1, w: 24, x: 0, y: 5 })
      + { templating+: { list+: templates } },
  },
}
