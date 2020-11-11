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
3. `git commit` + `git tag`
4. push master + tag to github
