# Free Router Helm chart

This chart owns the Free Router Deployment, Service, persistent data volume,
and optional standard Kubernetes `Ingress` or Gateway API `HTTPRoute`. Both
exposure resources are disabled by default. The chart intentionally has no
default hostname or Gateway name; provide those through the chart values for
each deployment environment.

The chart expects provider variables in the Secret named by
`envFromSecret` (default: `free-router-env`). Keep that Secret outside Git and
provide it through the deployment environment.
