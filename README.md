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
