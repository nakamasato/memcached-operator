# memcached-operator with Operator SDK (Go-based)

https://sdk.operatorframework.io/docs/building-operators/golang/quickstart/

## Docs

[Quickstart for Go-based Operators (GitHub Pages)](https://nakamasato.github.io/memcached-operator)

## Prerequisite

Install the followings:

1. `operator-sdk`: `operator-sdk: v1.22.2, kubernetes: v1.24.1, go: go1.18.4`
1. `go`:

You can upgrade the version with the following command:

```
./.upgrade-version.sh
```

## Contents
<!-- contents start -->
1. [Create a project](docs/01-initialize-operator.md)
1. [Create API (resource and controller) for Memcached](docs/02-create-api.md)
1. [Define Memcached API (Custom Resource Definition)](docs/03-define-api.md)
1. [Implement the controller](docs/04-implement-controller.md)
1. [Write controller tests](docs/05-write-controller-test.md)
1. [Deploy Operator](docs/06-deploy-operator.md)
1. [Continuous Integration](docs/07-ci.md)
<!-- contents end -->

Update contents:

```
./.update-content.sh
```
