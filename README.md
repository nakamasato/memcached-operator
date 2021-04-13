# Quickstart for Go-based Operators

https://sdk.operatorframework.io/docs/building-operators/golang/quickstart/

## Prerequisite

1. `operator-sdk`

    ```
    operator-sdk version
    operator-sdk version: "v1.5.0", commit: "98f30d59ade2d911a7a8c76f0169a7de0dec37a0", kubernetes version: "v1.19.4", go version: "go1.16.1", GOOS: "darwin", GOARCH: "amd64"
    ```

1. `go`

    ```
    go version
    go version go1.16.3 darwin/amd64
    ```

## Create Operator & deploy

1. Create operator

    ```
    operator-sdk init --domain example.com --repo github.com/example/memcached-operator
    ```

1. Add controller

    ```
    operator-sdk create api --group cache --version v1alpha1 --kind Memcached --resource --controller
    ```

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

    ```
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

## Implement CR and Controller

1. Define the API
    1. Update [api/v1alpha1/memcached_types.go]()
    1. `make generate` -> `controller-gen` to update [api/v1alpha1/zz_generated.deepcopy.go]()
    1. `make manifests` -> Make CRD manifests
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
