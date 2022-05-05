# 2. Create API (resource and controller) for Memcached

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
    /Users/nakamasato/repos/nakamasato/memcached-operator/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
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
