local cmutil = import 'configmap.jsonnet';
local outputConfMissingProjectAndZone = importstr 'fluentd/fluent.conf.template';
local outputConfMissingZone = std.strReplace(outputConfMissingProjectAndZone, '{{PROJECT_ID}}', std.extVar('PROJECT_ID'));
local outputConf = std.strReplace(outputConfMissingZone, '{{GCE_ZONE}}', std.extVar('GCE_ZONE'));

local data = {
  'fluent.conf': outputConf,
  'kubernetes.conf': importstr 'fluentd/kubernetes.conf',
  'prometheus.conf': importstr 'fluentd/prometheus.conf',
};

{
  kind: 'ConfigMap',
  apiVersion: 'v1',
  metadata: cmutil.metadata('fluentd-config', data),
  data: data,
}
