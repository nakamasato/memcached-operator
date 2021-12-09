# Quickstart for Go-based Operators

https://sdk.operatorframework.io/docs/building-operators/golang/quickstart/

## Prerequisite

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

## Steps
### 1. Initialize an operator.

```
operator-sdk init --domain example.com --repo github.com/example/memcached-operator
```

<details><summary>result</summary>

```
Writing kustomize manifests for you to edit...
Writing scaffold for you to edit...
Get controller runtime:
$ go get sigs.k8s.io/controller-runtime@v0.10.0
go: downloading sigs.k8s.io/controller-runtime v0.10.0
go: downloading k8s.io/utils v0.0.0-20210802155522-efc7438f0176
go: downloading k8s.io/component-base v0.22.1
go: downloading k8s.io/apiextensions-apiserver v0.22.1
Update dependencies:
$ go mod tidy
Next: define a resource with:
$ operator-sdk create api
```

</details>

## 2. Add API (resource and controller) for Memcached.

1. Add controller

    ```
    operator-sdk create api --group cache --version v1alpha1 --kind Memcached --resource --controller
    ```

    <details><summary>result</summary>

    ```
    Writing kustomize manifests for you to edit...
    Writing scaffold for you to edit...
    api/v1alpha1/memcached_types.go
    controllers/memcached_controller.go
    Update dependencies:
    $ go mod tidy
    Running make:
    $ make generate
    go: creating new go.mod: module tmp
    Downloading sigs.k8s.io/controller-tools/cmd/controller-gen@v0.7.0
    go: downloading sigs.k8s.io/controller-tools v0.7.0
    go: downloading github.com/fatih/color v1.12.0
    go: downloading golang.org/x/tools v0.1.5
    go: downloading github.com/gobuffalo/flect v0.2.3
    go: downloading github.com/mattn/go-isatty v0.0.12
    go get: installing executables with 'go get' in module mode is deprecated.
            To adjust and download dependencies of the current module, use 'go get -d'.
            To install using requirements of the current module, use 'go install'.
            To install ignoring the current module, use 'go install' with a version,
            like 'go install example.com/cmd@latest'.
            For more information, see https://golang.org/doc/go-get-install-deprecation
            or run 'go help get' or 'go help install'.
    go get: added github.com/fatih/color v1.12.0
    go get: added github.com/go-logr/logr v0.4.0
    go get: added github.com/gobuffalo/flect v0.2.3
    go get: added github.com/gogo/protobuf v1.3.2
    go get: added github.com/google/go-cmp v0.5.6
    go get: added github.com/google/gofuzz v1.1.0
    go get: added github.com/inconshreveable/mousetrap v1.0.0
    go get: added github.com/json-iterator/go v1.1.11
    go get: added github.com/mattn/go-colorable v0.1.8
    go get: added github.com/mattn/go-isatty v0.0.12
    go get: added github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd
    go get: added github.com/modern-go/reflect2 v1.0.1
    go get: added github.com/spf13/cobra v1.2.1
    go get: added github.com/spf13/pflag v1.0.5
    go get: added golang.org/x/mod v0.4.2
    go get: added golang.org/x/net v0.0.0-20210520170846-37e1c6afe023
    go get: added golang.org/x/sys v0.0.0-20210616094352-59db8d763f22
    go get: added golang.org/x/text v0.3.6
    go get: added golang.org/x/tools v0.1.5
    go get: added golang.org/x/xerrors v0.0.0-20200804184101-5ec99f83aff1
    go get: added gopkg.in/inf.v0 v0.9.1
    go get: added gopkg.in/yaml.v2 v2.4.0
    go get: added gopkg.in/yaml.v3 v3.0.0-20210107192922-496545a6307b
    go get: added k8s.io/api v0.22.2
    go get: added k8s.io/apiextensions-apiserver v0.22.2
    go get: added k8s.io/apimachinery v0.22.2
    go get: added k8s.io/klog/v2 v2.9.0
    go get: added k8s.io/utils v0.0.0-20210819203725-bdf08cb9a70a
    go get: added sigs.k8s.io/controller-tools v0.7.0
    go get: added sigs.k8s.io/structured-merge-diff/v4 v4.1.2
    go get: added sigs.k8s.io/yaml v1.2.0
    /Users/masato-naka/repos/nakamasato/memcached-operator/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
    Next: implement your new API and generate the manifests (e.g. CRDs,CRs) with:
    $ make manifests
    ```

    </details>

1. Try running the empty operator
    1. Install CRD.
        ```
        make install
        ```
    1. Run the controller.
        ```
        make run
        ```
    1. Create a new custom resource `Memcached`.
        ```
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```
    1. Check logs.
        ```
        kubectl logs $(kubectl get po -n memcached-operator-system | grep memcached-operator-controller-manager | awk '{print $1}') -c manager -n memcached-operator-system -f
        ```
    1. Cleanup.
        1. Delete CR.
            ```
            kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
            ```
        1. Stop the controller by `ctrl-c`.
        1. Uninstll the CRD.
            ```
            make uninstall
            ```

### 3. Define Memcached API (Custom Resource Definition).

1. Update [api/v1alpha1/memcached_types.go]()
1. `make generate` -> `controller-gen` to update [api/v1alpha1/zz_generated.deepcopy.go]()
1. `make manifests` -> Make CRD manifests
1. Update [config/samples/cache_v1alpha1_memcached.yaml]()

### 4. Implement the controller.
1. Implement the Controller
    1. Add reconcile loop (you can build, deploy and check logs with the commands above)
        1. Fetch Memcached instance.

            ```
            kubectl logs $(kubectl get po -n memcached-operator-system | grep memcached-operator-controller-manager | awk '{print $1}') -c manager -n memcached-operator-system -f
            2021-04-11T02:16:43.642Z        INFO    controllers.Memcached   Memchached resource found       {"memcached": "default/memcached-sample", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
            ```

        1. Check if the deployment already exists, if not create a new one.

            ```
            kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            kubectl get deploy memcached-sample
            NAME               READY   UP-TO-DATE   AVAILABLE   AGE
            memcached-sample   3/3     3            3           19s
            ```

            ```
            kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            2021-04-11T02:18:14.270Z        ERROR   controller-runtime.manager.controller.memcached Reconciler error       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "error": "Memcached.cache.example.com \"memcached-sample\" not found"}
            ```

            ```
            kubectl get deploy memcached-sample
            Error from server (NotFound): deployments.apps "memcached-sample" not found
            ```

        1. Ensure the deployment size is the same as the spec

            ```
            kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            kubectl get deploy memcached-sample
            NAME               READY   UP-TO-DATE   AVAILABLE   AGE
            memcached-sample   3/3     3            3           19s
            ```

            change the size to 2 in [config/samples/cache_v1alpha1_memcached.yaml]()

            ```
            kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            2021-04-11T02:32:56.649Z        INFO    controllers.Memcached      Update deployment size  {"memcached": "default/memcached-sample", "Deployment.Spec.Replicas": 2}
            ```

            ```
            kubectl get deploy memcached-sampleNAME               READY   UP-TO-DATE   AVAILABLE   AGE
            memcached-sample   2/2     2            2           63s
            ```

            ```
            kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            kubectl get deploy memcached-sample
            Error from server (NotFound): deployments.apps "memcached-sample" not found
            ```

            ```
            2021-04-11T02:36:28.168Z        ERROR   controller-runtime.manager.controller.memcached    Reconciler error   {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "error": "Memcached.cache.example.com \"memcached-sample\" not found"}
            ```

        1. Update the Memcached status with the pod names

            ```
            kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            kubectl get Memcached memcached-sample -o jsonpath='{.status}' | jq
            {
              "nodes": [
                "memcached-sample-6c765df685-fpqcd",
                "memcached-sample-6c765df685-n7xxh",
                "memcached-sample-6c765df685-x772f"
              ]
            }
            ```

            ```
            kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
            ```

            ```
            2021-04-11T03:06:40.253Z        INFO    controllers.Memcached   1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted       {"memcached": "default/memcached-sample"}
            ```

## Deployment

1. Build

    ```
    export OPERATOR_IMG="nakamasato/memcached-operator:v0.0.1"
    make docker-build docker-push IMG=$OPERATOR_IMG
    ```

1. Deploy operator

    ```
    make deploy IMG=$OPERATOR_IMG
    ```

1. Add CR

    ```
    kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
    ```

    ```yaml
    apiVersion: cache.example.com/v1alpha1
    kind: Memcached
    metadata:
      name: memcached-sample
    spec:
      size: 3
    ```

1. Check controller's log

    ```
    kubectl logs $(kubectl get po -n memcached-operator-system | grep memcached-operator-controller-manager | awk '{print $1}') -c manager -n memcached-operator-system -f
    ```

1. Uninstall operator

    ```
    make undeploy
    ```
