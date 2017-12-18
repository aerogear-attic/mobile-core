PKG     = github.com/aerogear/mobile-core
TOP_SRC_DIRS   = pkg
TEST_DIRS     ?= $(shell sh -c "find $(TOP_SRC_DIRS) -name \\*_test.go \
                   -exec dirname {} \\; | sort | uniq")
BIN_DIR := $(GOPATH)/bin
GOMETALINTER := $(BIN_DIR)/gometalinter
SHELL = /bin/bash
#CHANGE this if using a different url for openshift
OSCP = https://192.168.37.1:8443
NAMESPACE =project2
TAG=latest
LDFLAGS=-ldflags "-w -s -X main.Version=${TAG}"

.PHONY: ui
ui:
	cd ui && npm install && npm run bower install && npm run grunt build

apbs:
## Evaluate the presence of the TAG, to avoid evaluation of the nested shell script, during the read phase of make
    ifdef TAG
	@echo "Preparing $(TAG)"
        ifeq ($(shell git ls-files -m | wc -l),0)
			@echo "Doing the releae of the Aerogear MCP APBs"
			cp artifacts//openshift/template.json cmd/android-apb/roles/provision-android-app/templates
			cp artifacts/openshift/template.json cmd/cordova-apb/roles/provision-cordova-apb/templates
			cp artifacts/openshift/template.json cmd/ios-apb/roles/provision-ios-apb/templates
			git commit -m "[make apbs script] updating Openshift template for APBs" cmd/
			cd cmd/android-apb && make build_and_push TAG=$(TAG)
			cd cmd/ios-apb && make build_and_push TAG=$(TAG)
			cd cmd/cordova-apb && make build_and_push TAG=$(TAG)
        else
	        $(error Aborting release process, since local files are modified)
        endif
    else
		$(error No VERSION defined!)
    endif

clean:
	./installer/clean.sh
