# ubi-hadoop

Docker Image build of Hadoop from RHEL UBI base image.

# Workflow

## Basic workflow

1. Branch from `main`
2. Make changes
3. Increment build number file value
4. Commit and Push
5. Create PR merging into `main`
6. Get reviewed and approved

## Build new version of Hadoop

1. Check stable version [here](https://archive.apache.org/dist/hadoop/common/). If current version is desired, then stop.
2. Checkout `main` and pull
3. Update `Dockerfile` : `ARG HADOOP_VERSION` setting it to the version required.
4. Execute `get_hadoop_version.sh` to make sure that the output matches the new hive version.
6. Increment the value in `image_build_num.txt`
7. Run a test build by executing `pr_check.sh`
8. If successful, then commit changes and push branch.
9. Create a PR, this should execute a PR check script.
10. If successful, get approval and merge.

# Utility Scripts

* `get_hadoop_version.sh` : Get the current hadoop version from the `Dockerfile`.
* `get_image_tag.sh` : Return the image tag made from the hive version and the build number from `image_build_num.txt`
* `docker-build-dev.sh` : Executes a local test build of the docker image.

# Integration Scripts

* `pr_check.sh` : PR check script (You should not need to modify this)
* `build_deploy.sh` : Build and deploy to Red Hat cloudservices quay org. (You should not need to modify this script)

