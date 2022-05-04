# Quickstart for Go-based Operators

## About this tutorial

The original content is [https://sdk.operatorframework.io/docs/building-operators/golang/quickstart/](). In this tutorial, you can learn to create a go-based operator `memcached-operator` with [operator-sdk](https://sdk.operatorframework.io/) step by step.

What `memcached-operator` does:
- Manage a custom resource `Memcached`
    - `spec.size`: specify the number of memcached nodes.
    - `status.nodes`: contain information about nodes.
- Implement the reconciliation loop in the controller
    - Fetch Memcached instance
    - Create Deployment if not exists
    - Keep the Memcached's size and Deployment's replicas same
    - Update `status.nodes` with Pod's name.

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

1. [Initialize an operator](01-initialize-operator.md)
1. [Add API (resource and controller) for Memcached](02-create-api.md)
1. [Define Memcached API (Custom Resource Definition)](03-define-api.md)
1. [Implement the controller](04-implement-controller.md)
1. [Deploy with Deployment](05-deploy-with-deployment.md)
1. [Write controller tests](06-write-controller-test.md)
1. [CI](07-ci.md)
