# 2. Add API (resource and controller) for Memcached

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
    1. Check logs. (Just confirm the controller starts up successfully.)
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
