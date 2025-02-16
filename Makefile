# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

CONTROLLER_GEN ?= go run sigs.k8s.io/controller-tools/cmd/controller-gen
DIEGEN ?= go run dies.dev/diegen
GOIMPORTS ?= go run golang.org/x/tools/cmd/goimports
KUSTOMIZE ?= go run sigs.k8s.io/kustomize/kustomize/v4
YTT ?= go run github.com/k14s/ytt/cmd/ytt

.PHONY: all
all: test dist

.PHONY: test
test: generate fmt vet ## Run tests
	go test ./... -coverprofile cover.out

# Generate manifests e.g. CRD, RBAC etc.
.PHONY: manifests
manifests:
	$(CONTROLLER_GEN) crd:crdVersions=v1 rbac:roleName=manager-role webhook crd:maxDescLen=0 \
		paths="./pkg/apis/conventions/...;./pkg/controllers/..." \
		output:crd:dir=./config/crd/bases \
		output:rbac:dir=./config/rbac \
		output:webhook:dir=./config/webhook
	# cleanup duplicate resource generation
	@rm -f config/*.yaml

dist: dist/cartographer-conventions.yaml

dist/cartographer-conventions.yaml: generate manifests
	$(KUSTOMIZE) build config/default \
	  | $(YTT) -f - -f dist/strip-status.yaml -f dist/aks-webhooks.yaml \
	  > dist/cartographer-conventions.yaml

dist/third-party: dist/third-party/cert-manager.yaml

dist/third-party/cert-manager.yaml: Makefile
	curl -Ls https://github.com/cert-manager/cert-manager/releases/download/v1.7.2/cert-manager.yaml > dist/third-party/cert-manager.yaml	

# Run go fmt against code
.PHONY: fmt
fmt:
	$(GOIMPORTS) --local github.com/vmware-tanzu/cartographer-conventions -w pkg/ webhook/ samples/

# Run go vet against code
.PHONY: vet
vet:
	go vet ./...

.PHONY: generate
generate: generate-internal fmt ## Generate code

.PHONY: generate-internal
generate-internal:
	$(CONTROLLER_GEN) object:headerFile=./hack/boilerplate.go.txt paths="./..."
	$(DIEGEN) die:headerFile=./hack/boilerplate.go.txt paths="./..."

# Absolutely awesome: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print help for each make target
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
