# 5. Deploy with `Deployment`

1. Build docker image and push it to registry.

    ```bash
    export OPERATOR_IMG="<image registry name>:v0.0.1" # e.g. nakamasato/memcached-operator
    make docker-build docker-push IMG=$OPERATOR_IMG
    ```

1. Deploy operator.

    ```bash
    make deploy IMG=$OPERATOR_IMG
    ```

1. Add CR.

    ```bash
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

1. Check controller's log.

    ```bash
    kubectl logs $(kubectl get po -n memcached-operator-system | grep memcached-operator-controller-manager | awk '{print $1}') -c manager -n memcached-operator-system -f
    ```

1. Delete CR.

    ```bash
    kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
    ```

1. Uninstall operator.

    ```bash
    make undeploy
    ```
