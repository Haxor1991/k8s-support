local datatypes = ['ndt5', 'ndt7upload', 'ndt7download'];
local exp = import '../templates.jsonnet';
local expName = 'ndt';

exp.Experiment(expName, 2, 'pusher-' + std.extVar('PROJECT_ID'), "none", datatypes) + {
  spec+: {
    template+: {
      spec+: {
        containers+: [
          {
            name: 'ndt-server',
            image: 'measurementlab/ndt-server:' + exp.ndtVersion,
            args: [
              '-key=/certs/key.pem',
              '-cert=/certs/cert.pem',
              '-uuid-prefix-file=' + exp.uuid.prefixfile,
              '-prometheusx.listen-address=$(PRIVATE_IP):9990',
              '-datadir=/var/spool/' + expName,
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
                name: 'ndt-tls',
                readOnly: true,
              },
              exp.uuid.volumemount,
            ] + [
              exp.VolumeMount(expName + '/' + d) for d in datatypes
            ],
            ports: [
              {
                containerPort: 9990,
              },
            ],

          },
        ],
        // The default grace period after k8s sends SIGTERM is 30s. We
        // extend the grace period to give time for the following
        // shutdown sequence. After the grace period, kubernetes sends
        // SIGKILL.
        //
        // NDT pod shutdown sequence:
        //
        //  * k8s sends SIGTERM to NDT server
        //  * NDT server enables lame duck status
        //  * monitoring reads lame duck status (60s max)
        //  * mlab-ns updates server status (60s max)
        //  * all currently running tests complete. (30s max)
        //
        // Feel free to change this to a smaller value for speedy
        // sandbox deployments to enable faster compile-run-debug loops,
        // but 60+60+30=150 is what it needs to be for staging and prod.
        //
        // Only enable grace period where production traffic is possible.
        [if std.extVar('PROJECT_ID') != 'mlab-sandbox' then 'terminationGracePeriodSeconds']: 180,
        volumes+: [
          {
            name: 'ndt-tls',
            secret: {
              secretName: 'ndt-tls',
            },
          },
        ],
      },
    },
  },
}
