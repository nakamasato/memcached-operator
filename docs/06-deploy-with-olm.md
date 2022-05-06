# 6. Deploy with OLM


## Version

- operator-lifecycle-manager: [v0.21.1](https://github.com/operator-framework/operator-lifecycle-manager/releases/tag/v0.21.1)
## Steps

1. Build and push the latest docker image.

    In this example, I'm using my own docker hub registry: [nakamasato/memcached-operator](https://hub.docker.com/repository/docker/nakamasato/memcached-operator)

    ```
    IMG=nakamasato/memcached-operator:v0.0.1
    IMG=$IMG make docker-build docker-push
    ```

1. Install OLM into your Kubernetes cluster.

    ```
    operator-sdk olm install
    ```

    <details><summary>result</summary>

    ```
    INFO[0000] Fetching CRDs for version "latest"
    INFO[0000] Fetching resources for resolved version "latest"
    I0506 06:39:53.809752   84199 request.go:665] Waited for 1.042948805s due to client-side throttling, not priority and fairness, request: GET:https://127.0.0.1:61181/apis/node.k8s.io/v1beta1?timeout=32s
    INFO[0010] Creating CRDs and resources
    INFO[0010]   Creating CustomResourceDefinition "catalogsources.operators.coreos.com"
    INFO[0011]   Creating CustomResourceDefinition "clusterserviceversions.operators.coreos.com"
    INFO[0011]   Creating CustomResourceDefinition "installplans.operators.coreos.com"
    INFO[0011]   Creating CustomResourceDefinition "olmconfigs.operators.coreos.com"
    INFO[0011]   Creating CustomResourceDefinition "operatorconditions.operators.coreos.com"
    INFO[0011]   Creating CustomResourceDefinition "operatorgroups.operators.coreos.com"
    INFO[0012]   Creating CustomResourceDefinition "operators.operators.coreos.com"
    INFO[0012]   Creating CustomResourceDefinition "subscriptions.operators.coreos.com"
    INFO[0012]   Creating Namespace "olm"
    INFO[0012]   Creating Namespace "operators"
    INFO[0012]   Creating ServiceAccount "olm/olm-operator-serviceaccount"
    INFO[0012]   Creating ClusterRole "system:controller:operator-lifecycle-manager"
    INFO[0012]   Creating ClusterRoleBinding "olm-operator-binding-olm"
    INFO[0013]   Creating OLMConfig "cluster"
    I0506 06:40:03.832612   84199 request.go:665] Waited for 1.206894542s due to client-side throttling, not priority and fairness, request: GET:https://127.0.0.1:61181/apis/scheduling.k8s.io/v1?timeout=32s
    INFO[0015]   Creating Deployment "olm/olm-operator"
    INFO[0015]   Creating Deployment "olm/catalog-operator"
    INFO[0015]   Creating ClusterRole "aggregate-olm-edit"
    INFO[0015]   Creating ClusterRole "aggregate-olm-view"
    INFO[0015]   Creating OperatorGroup "operators/global-operators"
    INFO[0015]   Creating OperatorGroup "olm/olm-operators"
    INFO[0016]   Creating ClusterServiceVersion "olm/packageserver"
    INFO[0016]   Creating CatalogSource "olm/operatorhubio-catalog"
    INFO[0016] Waiting for deployment/olm-operator rollout to complete
    INFO[0016]   Waiting for Deployment "olm/olm-operator" to rollout: 0 of 1 updated replicas are available
    INFO[0048]   Deployment "olm/olm-operator" successfully rolled out
    INFO[0048] Waiting for deployment/catalog-operator rollout to complete
    INFO[0048]   Deployment "olm/catalog-operator" successfully rolled out
    INFO[0048] Waiting for deployment/packageserver rollout to complete
    INFO[0048]   Waiting for Deployment "olm/packageserver" to rollout: 0 of 2 updated replicas are available
    INFO[0068]   Deployment "olm/packageserver" successfully rolled out
    INFO[0069] Successfully installed OLM version "latest"

    NAME                                            NAMESPACE    KIND                        STATUS
    catalogsources.operators.coreos.com                          CustomResourceDefinition    Installed
    clusterserviceversions.operators.coreos.com                  CustomResourceDefinition    Installed
    installplans.operators.coreos.com                            CustomResourceDefinition    Installed
    olmconfigs.operators.coreos.com                              CustomResourceDefinition    Installed
    operatorconditions.operators.coreos.com                      CustomResourceDefinition    Installed
    operatorgroups.operators.coreos.com                          CustomResourceDefinition    Installed
    operators.operators.coreos.com                               CustomResourceDefinition    Installed
    subscriptions.operators.coreos.com                           CustomResourceDefinition    Installed
    olm                                                          Namespace                   Installed
    operators                                                    Namespace                   Installed
    olm-operator-serviceaccount                     olm          ServiceAccount              Installed
    system:controller:operator-lifecycle-manager                 ClusterRole                 Installed
    olm-operator-binding-olm                                     ClusterRoleBinding          Installed
    cluster                                                      OLMConfig                   Installed
    olm-operator                                    olm          Deployment                  Installed
    catalog-operator                                olm          Deployment                  Installed
    aggregate-olm-edit                                           ClusterRole                 Installed
    aggregate-olm-view                                           ClusterRole                 Installed
    global-operators                                operators    OperatorGroup               Installed
    olm-operators                                   olm          OperatorGroup               Installed
    packageserver                                   olm          ClusterServiceVersion       Installed
    operatorhubio-catalog                           olm          CatalogSource               Installed
    ```

    </details>

    Check:

    ```
    kubectl get po -n olm
    NAME                                READY   STATUS    RESTARTS      AGE
    catalog-operator-7bfdc86d78-ftsqp   1/1     Running   0             3m32s
    olm-operator-745fb9c45-xn9jq        1/1     Running   0             3m32s
    operatorhubio-catalog-5spvd         1/1     Running   3 (50s ago)   3m1s
    packageserver-b9659cb48-cmlfn       1/1     Running   0             2m59s
    packageserver-b9659cb48-swpcm       1/1     Running   0             2m59s
    ```

1. Bundle your operator with `BUNDLE_IMG`.

    ```
    IMG=$IMG make bundle
    ```

    <details>

    ```
    /Users/nakamasato/repos/nakamasato/memcached-operator/bin/controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
    operator-sdk generate kustomize manifests -q
    cd config/manager && /Users/nakamasato/repos/nakamasato/memcached-operator/bin/kustomize edit set image controller=nakamasato/memcached-operator:v0.0.1
    /Users/nakamasato/repos/nakamasato/memcached-operator/bin/kustomize build config/manifests | operator-sdk generate bundle -q --overwrite --version 0.0.1
    INFO[0001] Creating bundle/metadata/annotations.yaml
    INFO[0001] Creating bundle.Dockerfile
    INFO[0001] Bundle metadata generated suceessfully
    operator-sdk bundle validate ./bundle
    INFO[0000] All validation tests have completed successfully
    ```

    </details>

    Use another repository for bundle: [nakamasato/memcached-operator-bundle](https://hub.docker.com/repository/docker/nakamasato/memcached-operator-bundle)

    ```
    make bundle-build bundle-push BUNDLE_IMG=docker.io/nakamasato/memcached-operator-bundle:v0.0.1
    ```

    <details><summary>result</summary>

    ```
    make bundle-build bundle-push BUNDLE_IMG=docker.io/nakamasato/memcached-operator-bundle:v0.0.1
    docker build -f bundle.Dockerfile -t docker.io/nakamasato/memcached-operator-bundle:v0.0.1 .
    [+] Building 0.5s (7/7) FINISHED
     => [internal] load build definition from bundle.Dockerfile                                             0.1s
     => => transferring dockerfile: 44B                                                                     0.0s
     => [internal] load .dockerignore                                                                       0.0s
     => => transferring context: 35B                                                                        0.0s
     => [internal] load build context                                                                       0.1s
     => => transferring context: 741B                                                                       0.0s
     => CACHED [1/3] COPY bundle/manifests /manifests/                                                      0.0s
     => CACHED [2/3] COPY bundle/metadata /metadata/                                                        0.0s
     => CACHED [3/3] COPY bundle/tests/scorecard /tests/scorecard/                                          0.0s
     => exporting to image                                                                                  0.0s
     => => exporting layers                                                                                 0.0s
     => => writing image sha256:7f35a82eb086d5476d518c14d3b467d628032d74a083cd8cb2991ccab57e0707            0.0s
     => => naming to docker.io/nakamasato/memcached-operator-bundle:v0.0.1                                  0.0s

    Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
    /Library/Developer/CommandLineTools/usr/bin/make docker-push IMG=docker.io/nakamasato/memcached-operator-bundle:v0.0.1
    docker push docker.io/nakamasato/memcached-operator-bundle:v0.0.1
    The push refers to repository [docker.io/nakamasato/memcached-operator-bundle]
    018b84f0bc42: Mounted from nakamasato/memcached-operator-bundle-v0.0.1
    1fe6adf17d6a: Mounted from nakamasato/memcached-operator-bundle-v0.0.1
    3e3e3b47b77a: Mounted from nakamasato/memcached-operator-bundle-v0.0.1
    v0.0.1: digest: sha256:22b7a22279a5f45d9b4eae27ed5e537ae5aeb53ed4ac6572108ba73cf22a8a7a size: 939
    ```

    </details>

1. Install `memcached-operator` with OLM.

    ```
    operator-sdk run bundle docker.io/nakamasato/memcached-operator-bundle:v0.0.1
    ```

    <details><summary>result</summary>

    ```
    INFO[0023] Successfully created registry pod: docker-io-nakamasato-memcached-operator-bundle-v0-0-1
    INFO[0023] Created CatalogSource: memcached-operator-catalog
    INFO[0023] OperatorGroup "operator-sdk-og" created
    INFO[0023] Created Subscription: memcached-operator-v0-0-1-sub
    INFO[0032] Approved InstallPlan install-wq7t2 for the Subscription: memcached-operator-v0-0-1-sub
    INFO[0032] Waiting for ClusterServiceVersion "default/memcached-operator.v0.0.1" to reach 'Succeeded' phase
    INFO[0032]   Waiting for ClusterServiceVersion "default/memcached-operator.v0.0.1" to appear
    INFO[0066]   Found ClusterServiceVersion "default/memcached-operator.v0.0.1" phase: Installing
    INFO[0097]   Found ClusterServiceVersion "default/memcached-operator.v0.0.1" phase: Succeeded
    INFO[0097] OLM has successfully installed "memcached-operator.v0.0.1"
    ```

    </details>

    Check Pods:

    ```
    kubectl get po
    NAME                                                              READY   STATUS      RESTARTS   AGE
    d71c67e797ef5c5fbbaed16811c5e6052504e58d7c9b2b6e9c19bee2699brks   0/1     Completed   0          112s
    docker-io-nakamasato-memcached-operator-bundle-v0-0-1             1/1     Running     0          2m6s
    memcached-operator-controller-manager-c9457868d-s7m2w             2/2     Running     0          78s
    ```

1. Create Custom Resource.

    ```
    kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
    ```

    Check:
    ```
    kubectl get memcached,deploy memcached-sample
    NAME                                           AGE
    memcached.cache.example.com/memcached-sample   40s

    NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
    deployment.apps/memcached-sample   2/2     2            2           40s
    ```

1. Clean up the custom resource.

    ```
    kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
    ```

1. Uninstall `memcached-operator`.

    ```
    operator-sdk cleanup memcached-operator
    ```

1. Uninstall OLM.

    ```
    operator-sdk olm uninstall
    ```

    <details><summary>result</summary>

    ```
    INFO[0000] Fetching CRDs for version "v0.21.1"
    INFO[0000] Fetching resources for resolved version "v0.21.1"
    INFO[0003] Uninstalling resources for version "v0.21.1"
    INFO[0003]   Deleting CustomResourceDefinition "catalogsources.operators.coreos.com"
    INFO[0003]   Deleting CustomResourceDefinition "clusterserviceversions.operators.coreos.com"
    INFO[0011]   Deleting CustomResourceDefinition "installplans.operators.coreos.com"
    INFO[0018]   Deleting CustomResourceDefinition "olmconfigs.operators.coreos.com"
    INFO[0019]   Deleting CustomResourceDefinition "operatorconditions.operators.coreos.com"
    INFO[0019]   Deleting CustomResourceDefinition "operatorgroups.operators.coreos.com"
    INFO[0023]   Deleting CustomResourceDefinition "operators.operators.coreos.com"
    INFO[0024]   Deleting CustomResourceDefinition "subscriptions.operators.coreos.com"
    INFO[0024]   Deleting Namespace "olm"
    INFO[0037]   Deleting Namespace "operators"
    INFO[0043]   Deleting ServiceAccount "olm/olm-operator-serviceaccount"
    INFO[0043]     ServiceAccount "olm/olm-operator-serviceaccount" does not exist
    INFO[0043]   Deleting ClusterRole "system:controller:operator-lifecycle-manager"
    INFO[0043]   Deleting ClusterRoleBinding "olm-operator-binding-olm"
    INFO[0043]   Deleting OLMConfig "cluster"
    INFO[0043]     OLMConfig "cluster" does not exist
    INFO[0044]   Deleting Deployment "olm/olm-operator"
    INFO[0044]     Deployment "olm/olm-operator" does not exist
    INFO[0044]   Deleting Deployment "olm/catalog-operator"
    INFO[0044]     Deployment "olm/catalog-operator" does not exist
    INFO[0044]   Deleting ClusterRole "aggregate-olm-edit"
    INFO[0044]   Deleting ClusterRole "aggregate-olm-view"
    INFO[0044]   Deleting OperatorGroup "operators/global-operators"
    INFO[0044]     OperatorGroup "operators/global-operators" does not exist
    INFO[0044]   Deleting OperatorGroup "olm/olm-operators"
    INFO[0044]     OperatorGroup "olm/olm-operators" does not exist
    INFO[0044]   Deleting ClusterServiceVersion "olm/packageserver"
    INFO[0044]     ClusterServiceVersion "olm/packageserver" does not exist
    INFO[0044]   Deleting CatalogSource "olm/operatorhubio-catalog"
    INFO[0044]     CatalogSource "olm/operatorhubio-catalog" does not exist
    INFO[0044] Successfully uninstalled OLM version "v0.21.1"
    ```

    </details>
