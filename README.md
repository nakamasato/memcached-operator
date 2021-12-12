# Quickstart for Go-based Operators

https://sdk.operatorframework.io/docs/building-operators/golang/quickstart/

## Docs

[Quickstart for Go-based Operators (GitHub Pages)](https://nakamasato.github.io/memcached-operator)

## Prerequisite

Install the followings:

1. `operator-sdk`

    ```
    operator-sdk version
    operator-sdk version: "v1.15.0", commit: "f6326e832a8a5e5453d0ad25e86714a0de2c0fc8", kubernetes version: "v1.21", go version: "go1.17.2", GOOS: "darwin", GOARCH: "amd64"
    ```

1. `go`

    ```
    go version
    go version go1.17.3 darwin/amd64
    ```

## Contents

1. [Initialize an operator](docs/01-initialize-operator.md)
1. [Add API (resource and controller) for Memcached](docs/02-create-api.md)
1. [Define Memcached API (Custom Resource Definition)](docs/03-define-api.md)
1. [Implement the controller](docs/04-implement-controller.md)
1. [Deploy with Deployment](docs/05-deploy-with-deployment.md)
1. [Write controller tests](docs/06-write-controller-test.md)
1. [CI](docs/07-ci.md)
...
