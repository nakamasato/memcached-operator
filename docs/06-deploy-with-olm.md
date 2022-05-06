# 6. Deploy with OLM

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

    In this example, I'm using my own docker hub registry: https://hub.docker.com/repository/docker/nakamasato/memcached-operator

    ```
    IMG=nakamasato/memcached-operator:v0.0.1
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

    ```
    make bundle-build bundle-push BUNDLE_IMG=$IMG
    ```

    <details><summary>result</summary>

    ```
    docker build -f bundle.Dockerfile -t nakamasato/memcached-operator:v0.0.1 .
    [+] Building 0.8s (7/7) FINISHED
     => [internal] load build definition from bundle.Dockerfile                                                  0.1s
     => => transferring dockerfile: 970B                                                                         0.0s
     => [internal] load .dockerignore                                                                            0.0s
     => => transferring context: 171B                                                                            0.0s
     => [internal] load build context                                                                            0.1s
     => => transferring context: 12.13kB                                                                         0.1s
     => [1/3] COPY bundle/manifests /manifests/                                                                  0.0s
     => [2/3] COPY bundle/metadata /metadata/                                                                    0.1s
     => [3/3] COPY bundle/tests/scorecard /tests/scorecard/                                                      0.0s
         => exporting to image                                                                                       0.1s
         => => exporting layers                                                                                      0.1s
     => => writing image sha256:dedce44bfa7f53e89a6d57daeec3d2f745607405b131f7b0fbca3bf80538a381                 0.0s
     => => naming to docker.io/nakamasato/memcached-operator:v0.0.1                                              0.0s

    Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
    /Library/Developer/CommandLineTools/usr/bin/make docker-push IMG=nakamasato/memcached-operator:v0.0.1
    docker push nakamasato/memcached-operator:v0.0.1
    The push refers to repository [docker.io/nakamasato/memcached-operator]
    4748905d6dc6: Pushed
    8973f608ef2b: Pushed
    dd7513d00c74: Pushed
    v0.0.1: digest: sha256:416d90b81be5c0c347c4a75b2ab84060aa2f5de3660bce57a0a4fba88ce7ea61 size: 939
    ```

    </details>

1. Install `memcached-operator` with OLM.

    ```
    operator-sdk run bundle docker.io/nakamasato/memcached-operator:v0.0.1
    ```

    <details><summary>result</summary>

    ```

    ```

    </details>

1. Cleanup
    ```
    operator-sdk cleanup memcached-operator
    ```
