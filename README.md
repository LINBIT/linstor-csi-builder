# LINSTOR CSI builder

Build + package [linstor-csi] in a Docker image.

[linstor-csi]: https://github.com/piraeusdatastore/linstor-csi

## Create a new release

1. `./linstor-csi` to point to the new upstream commit.
2. edit `./Dockerfile` to use the new release version as default for `ARG SEMVER`.
   There is a make target to do that for you:
   ```
   make prepare-release SEMVER=<version>
   ```
3. Add changelog entries [here](./debian/changelog) and [here](./linstor-csi.spec).
4. `git commit` + `git tag`
5. push master + tag to gitlab

## Standalone deployment

[`examples/standalone`](./examples/standalone) renders the CSI components using the
`drbd.io` images, for use with an existing LINSTOR cluster. RWX volumes via NFS are disabled.

1. Set `LINSTOR_CONTROLLER_URL` in [`settings.yaml`](./examples/standalone/settings.yaml).
2. Add your `drbd.io` credentials to
   [`drbdio-pull-secret.json`](./examples/standalone/drbdio-pull-secret.json).
3. Deploy:
   ```
   kubectl kustomize examples/standalone | kubectl apply --server-side -f -
   ```
