# Upstream Release Process

## Release of independent apbs

The APBs use automatic builds in the aerogearcatalog org in Dockerhub.

To create a new build you can create a tag or a release on the repo such as 1.0.0-alpha and this will cause a build to be done of the image from that ref. 


If you want to update a version but keep the same tag you must first delete the existing tag and then recreate it.

To delete a tag use the git command line and run

```
git push --delete origin <tag>

```
Then recreate the tag at a new ref and a new build will be done. Note this will replace the old image.


# Release of the mobile core installer

To mark a particular commit as a release. Create a release via the github UI and pick the commit you want to use, this will create a tag at that commit.

# Release of the mobile custom console image.
Currently we have a custom image for the web console. To create an new image you should do the following:


## Creating Custom Console Container


```sh
go get github.com/openshift/origin-web-common
go get github.com/openshift/origin-web-catalog
go get github.com/openshift/origin-web-console
```
and add the aerogear upstream to each of these repos
```
cd $GOPATH/src/github.com/openshift/origin-web-console && git remote add aerogear git@github.com:aerogear/origin-web-console.git

cd $GOPATH/src/github.com/openshift/origin-web-catalog && git remote add aerogear git@github.com:aerogear/origin-web-catalog.git

cd $GOPATH/src/github.com/openshift/origin-web-common && git remote add aerogear git@github.com:aerogear/origin-web-common.git

```

Next get the web console server

```
go get github.com/openshift/origin-web-console-server
```

This should install the origin-web-console-server repo at:

```sh
$GOPATH/src/github.com/origin/openshift-web-console-server
```

## Steps
Based on https://github.com/openshift/origin-web-console#contributing-to-the-primary-repositories

in the origin-web-common repo run:
```
git fetch --all
git checkout aerogear/aerogear-mcp
./hack/install-deps.sh
grunt build
bower link
```

in the origin-web-catalog repo run:
```
git fetch --all
git checkout aerogear/aerogear-mcp
./hack/install-deps.sh
npm run build
bower link
```

in the origin-web-console repo run:
```
git fetch --all
git checkout aerogear/aerogear-mcp
./hack/clean-deps.sh
./hack/install-deps.sh
bower link origin-web-catalog
bower link origin-web-common
grunt build
```

In the origin-web-console-server repo, run:
```sh
CONSOLE_REPO_PATH=$GOPATH/src/github.com/openshift/origin-web-console make vendor-console
#note I had to change constants.sh and set OS_REQUIRED_GO_VERSION=1.10.2
make clean build
OS_BUILD_ENV_PRESERVE=_output/local/bin hack/env make build-images
docker tag openshift/origin-web-console:latest <YOUR_TAG_FOR_THIS_IMAGE>
docker push <YOUR_TAG_FOR_THIS_IMAGE>
```
