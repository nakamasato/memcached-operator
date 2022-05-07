# memcached-operator with Operator SDK (Go-based)

https://sdk.operatorframework.io/docs/building-operators/golang/quickstart/

## Docs

[Quickstart for Go-based Operators (GitHub Pages)](https://nakamasato.github.io/memcached-operator)

## Prerequisite

Install the followings:

1. `operator-sdk`

    ```
    operator-sdk version
    operator-sdk version: "v1.19.1", commit: "079d8852ce5b42aa5306a1e33f7ca725ec48d0e3", kubernetes version: "v1.23", go version: "go1.18.1", GOOS: "darwin", GOARCH: "amd64"
    ```

1. `go`

    ```
    go version
    go version go1.18.1 darwin/amd64
    ```

You can upgrade the version with the following command:

```
./upgrade-version.sh
```

## Contents
<!-- contents start -->
1. [Create a project](docs/01-initialize-operator.md)
1. [Create API (resource and controller) for Memcached](docs/02-create-api.md)
1. [Define Memcached API (Custom Resource Definition)](docs/03-define-api.md)
1. [Implement the controller](docs/04-implement-controller.md)
1. [Deploy with `Deployment`](docs/05-deploy-with-deployment.md)
1. [Deploy with OLM](docs/06-deploy-with-olm.md)
1. [Write controller tests](docs/07-write-controller-test.md)
1. [Continuous Integration](docs/08-ci.md)
<!-- contents end -->

Update contents:

```
./update-content.sh
```
