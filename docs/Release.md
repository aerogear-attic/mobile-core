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
Currently we have a custom image for the web console. To create an new image you should use the following doc
https://github.com/aerogear/minishift-mobilecore-addon/blob/master/docs/create-custom-console-container.adoc