local datatypes = ['dash'];
local exp = import '../templates.jsonnet';
local expName = 'neubot';

exp.Experiment(expName, 10, 'pusher-' + std.extVar('PROJECT_ID'), "none", datatypes) + {
  spec+: {
    template+: {
      spec+: {
        containers+: [
            {
              name: 'dash',
              image: 'measurementlab/dash:v0.4.1',
            args: [
              '-datadir=/var/spool/' + expName,
              '-prometheusx.listen-address=$(PRIVATE_IP):9990',
              '-http-listen-address=:80',
              '-https-listen-address=:443',
              '-tls-cert=/certs/tls.crt',
              '-tls-key=/certs/tls.key',
            ],
            env: [
              {
                name: 'PRIVATE_IP',
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'status.podIP',
                  },
                },
              },
            ],
            volumeMounts: [
              {
                mountPath: '/certs',
                name: 'measurement-lab-org-tls',
                readOnly: true,
              },
            ] + [
              exp.VolumeMount(expName + '/' + d) for d in datatypes
            ],
            ports: [
              {
                containerPort: 9990,
              },
            ],
            livenessProbe+: {
              httpGet: {
                path: '/metrics',
                port: 9990,
              },
              initialDelaySeconds: 5,
              periodSeconds: 30,
            },
          },
        ],
        [if std.extVar('PROJECT_ID') != 'mlab-sandbox' then 'terminationGracePeriodSeconds']: 180,
        volumes+: [
          {
            name: 'measurement-lab-org-tls',
            secret: {
              secretName: 'measurement-lab-org-tls',
            },
          },
        ],
      },
    },
  },
}
