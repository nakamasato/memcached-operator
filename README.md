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

### 2. Add API (resource and controller) for Memcached.

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

### 3. Define Memcached API (Custom Resource Definition).

1. Update [api/v1alpha1/memcached_types.go]()
1. `make generate` -> `controller-gen` to update [api/v1alpha1/zz_generated.deepcopy.go]()
1. `make manifests` -> Make CRD manifests
1. Update [config/samples/cache_v1alpha1_memcached.yaml]()

### 4. Implement the controller.
#### 4.1. Fetch Memcached instance.

1. Write the following lines in `Reconcile` function in [controllers/memcached_controller.go]().

    ```go
    func (r *MemcachedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result,     error) {
        log := log.FromContext(ctx)

        // 1. Fetch the Memcached instance
        memcached := &cachev1alpha1.Memcached{}
        err := r.Get(ctx, req.NamespacedName, memcached)
        if err != nil {
            if errors.IsNotFound(err) {
                log.Info("1. Fetch the Memcached instance. Memcached resource not found.     Ignoring since object must be deleted")
                return ctrl.Result{}, nil
            }
            // Error reading the object - requeue the request.
            log.Error(err, "1. Fetch the Memcached instance. Failed to get Mmecached")
            return ctrl.Result{}, err
        }
        log.Info("1. Fetch the Memcached instance. Memchached resource found", "memcached.Name",     memcached.Name, "memcached.Namespace", memcached.Namespace)
        return ctrl.Result{}, nil
    }
    ```

1. Check
    1. Run the controller.
        ```bash
        make run
        ```
    1. Apply a `Memcached` (CR).
        ```bash
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```
    1. Check logs.

        ```bash
        2021-12-10T12:14:10.123+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        ```

    1. Delete the CR.
        ```bash
        kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Check logs.
        ```bash
        2021-12-10T12:15:37.234+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        ```
    1. Stop the controller.

#### 4.2 Check if the deployment already exists, and create one if not exists.

1. Add necessary packages to `import`.
    ```go
    import (
        ...
        "k8s.io/apimachinery/pkg/types"
        ...

        appsv1 "k8s.io/api/apps/v1"
        corev1 "k8s.io/api/core/v1"
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

        ...
    )
    ```

1. Add the following logics to `Reconcile` function.

    ```go
    // 2. Check if the deployment already exists, if not create a new one
    found := &appsv1.Deployment{}
    err = r.Get(ctx, types.NamespacedName{Name: memcached.Name, Namespace: memcached.Namespace}, found)
    if err != nil && errors.IsNotFound(err) {
            // Define a new deployment
            dep := r.deploymentForMemcached(memcached)
            log.Info("2. Check if the deployment already exists, if not create a new one. Creating a new Deployment", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
            err = r.Create(ctx, dep)
            if err != nil {
                    log.Error(err, "2. Check if the deployment already exists, if not create a new one. Failed to create new Deployment", "Deployment.Namespace", dep.Namespace, "Deployment.Name", dep.Name)
                    return ctrl.Result{}, err
            }
            // Deployment created successfully - return and requeue
            return ctrl.Result{Requeue: true}, nil
    } else if err != nil {
            log.Error(err, "2. Check if the deployment already exists, if not create a new one. Failed to get Deployment")
            return ctrl.Result{}, err
    }
    ```
1. Create `deploymentForMemcached` and `labelsForMemcached` functions.

    <details><summary>deploymentForMemcached</summary>

    ```go
    // deploymentForMemcached returns a memcached Deployment object
    func (r *MemcachedReconciler) deploymentForMemcached(m *cachev1alpha1.Memcached) *appsv1.Deployment {
        ls := labelsForMemcached(m.Name)
        replicas := m.Spec.Size

        dep := &appsv1.Deployment{
                ObjectMeta: metav1.ObjectMeta{
                        Name:      m.Name,
                        Namespace: m.Namespace,
                },
                Spec: appsv1.DeploymentSpec{
                        Replicas: &replicas,
                        Selector: &metav1.LabelSelector{
                                MatchLabels: ls,
                        },
                        Template: corev1.PodTemplateSpec{
                                ObjectMeta: metav1.ObjectMeta{
                                        Labels: ls,
                                },
                                Spec: corev1.PodSpec{
                                        Containers: []corev1.Container{{
                                                Image:   "memcached:1.4.36-alpine",
                                                Name:    "memcached",
                                                Command: []string{"memcached", "-m=64", "-o", "modern", "-v"},
                                                Ports: []corev1.ContainerPort{{
                                                        ContainerPort: 11211,
                                                        Name:          "memcached",
                                                }},
                                        }},
                                },
                        },
                },
        }
        // Set Memcached instance as the owner and controller
        ctrl.SetControllerReference(m, dep, r.Scheme)
        return dep
    }
    ```

    </details>

    <details><summary>labelsForMemcached</summary>

    ```go
    // labelsForMemcached returns the labels for selecting the resources
    // belonging to the given memcached CR name.
    func labelsForMemcached(name string) map[string]string {
        return map[string]string{"app": "memcached", "memcached_cr": name}
    }
    ```

    </details>
1. Add necessary `RBAC` to the reconciler.

    ```diff
    //+kubebuilder:rbac:groups=cache.example.com,resources=memcacheds,verbs=get;list;watch;create;update;patch;delete
    //+kubebuilder:rbac:groups=cache.example.com,resources=memcacheds/status,verbs=get;update;patch
    //+kubebuilder:rbac:groups=cache.example.com,resources=memcacheds/finalizers,verbs=update
    + //+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
    ```

1. Add `Owns(&appsv1.Deployment{})` to the controller manager.

    ```go
    // SetupWithManager sets up the controller with the Manager.
    func (r *MemcachedReconciler) SetupWithManager(mgr ctrl.Manager) error {
        return ctrl.NewControllerManagedBy(mgr).
            For(&cachev1alpha1.Memcached{}).
            Owns(&appsv1.Deployment{}).
            Complete(r)
    }
    ```

1. Check
    1. Run the controller.
        ```bash
        make run
        ```
    1. Apply a `Memcached` (CR).
        ```bash
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```
    1. Check logs.

        ```bash
        2021-12-10T12:34:34.587+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:34.587+0900    INFO    controller.memcached    2. Check if the deployment already exists, if not create a new one. Creating a new Deployment       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "Deployment.Namespace": "default", "Deployment.Name": "memcached-sample"}
        2021-12-10T12:34:34.599+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:34.604+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:34.648+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:34.662+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:34.724+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:43.285+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:46.333+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:34:48.363+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        ```

        There are ten lines of logs:
        1. When `Memcached` object is created.
        1. Create `Deployment`.
        1. When `Deployment` is created.
        1. 8 more events are created accordingly.


    1. Check `Deployment`.

        ```
        kubectl get deploy memcached-sample
        NAME               READY   UP-TO-DATE   AVAILABLE   AGE
        memcached-sample   3/3     3            3           19s
        ```

    1. Delete the CR.
        ```bash
        kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Check logs.
        ```bash
        2021-12-10T12:38:50.473+0900    INFO    controller.memcached 1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        2021-12-10T12:38:50.512+0900    INFO    controller.memcached 1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        ```
    1. Check `Deployment`.
        ```
        kubectl get deploy
        No resources found in default namespace.
        ```
    1. Stop the controller.

#### 4.3 Ensure the deployment size is the same as the spec.

1. Add the following lines to `Reconcile` function.

    ```go
    // 3. Ensure the deployment size is the same as the spec
    size := memcached.Spec.Size
    if *found.Spec.Replicas != size {
            found.Spec.Replicas = &size
            err = r.Update(ctx, found)
            if err != nil {
                    log.Error(err, "3. Ensure the deployment size is the same as the spec. Failed to update Deployment", "Deployment.Namespace", found.Namespace, "Deployment.Name", found.Name)
                    return ctrl.Result{}, err
            }
            // Spec updated - return and requeue
            log.Info("3. Ensure the deployment size is the same as the spec. Update deployment size", "Deployment.Spec.Replicas", size)
            return ctrl.Result{Requeue: true}, nil
    }
    ```
1. Check
    1. Run the controller.
        ```bash
        make run
        ```
    1. Apply a `Memcached` (CR).
        ```bash
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```
    1. Check `Deployment`.

        ```
        kubectl get deploy memcached-sample
        NAME               READY   UP-TO-DATE   AVAILABLE   AGE
        memcached-sample   3/3     3            3           19s
        ```

    1. Change the size to 2 in [config/samples/cache_v1alpha1_memcached.yaml]()

        ```
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Check logs.

        ```bash
        2021-12-10T12:59:09.880+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:59:09.888+0900    INFO    controller.memcached    3. Ensure the deployment size is the same as the spec. Update deployment size{"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "Deployment.Spec.Replicas": 2}
        2021-12-10T12:59:09.888+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:59:09.894+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:59:09.911+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T12:59:09.951+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        ```

    1. Check `Deployment`.

        ```
        kubectl get deploy
        NAME               READY   UP-TO-DATE   AVAILABLE   AGE
        memcached-sample   2/2     2            2           115s
        ```

    1. Delete the CR.
        ```bash
        kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Check logs.
        ```bash
        2021-12-10T13:00:50.149+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        2021-12-10T13:00:50.185+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        ```
    1. Check `Deployment`.
        ```
        kubectl get deploy
        No resources found in default namespace.
        ```
    1. Stop the controller.


#### 4.2 Update the Memcached status with the pod names.

1. Add `"reflect"` to `import`.
1. Add the following logic to `Reconcile` functioin.

    ```go
    // 4. Update the Memcached status with the pod names
    // List the pods for this memcached's deployment
    podList := &corev1.PodList{}
    listOpts := []client.ListOption{
            client.InNamespace(memcached.Namespace),
            client.MatchingLabels(labelsForMemcached(memcached.Name)),
    }
    if err = r.List(ctx, podList, listOpts...); err != nil {
            log.Error(err, "4. Update the Memcached status with the pod names. Failed to list pods", "Memcached.Namespace", memcached.Namespace, "Memcached.Name", memcached.Name)
            return ctrl.Result{}, err
    }
    podNames := getPodNames(podList.Items)
    log.Info("4. Update the Memcached status with the pod names. Pod list", "podNames", podNames)
    // Update status.Nodes if needed
    if !reflect.DeepEqual(podNames, memcached.Status.Nodes) {
            memcached.Status.Nodes = podNames
            err := r.Status().Update(ctx, memcached)
            if err != nil {
                    log.Error(err, "4. Update the Memcached status with the pod names. Failed to update Memcached status")
                    return ctrl.Result{}, err
            }
    }
    log.Info("4. Update the Memcached status with the pod names. Update memcached.Status", "memcached.Status.Nodes", memcached.Status.Nodes)
    ```
1. Add `getPodNames` function.

    ```go
    // getPodNames returns the pod names of the array of pods passed in
    func getPodNames(pods []corev1.Pod) []string {
        var podNames []string
        for _, pod := range pods {
                podNames = append(podNames, pod.Name)
        }
        return podNames
    }
    ```
1. Add necessary `RBAC`.
    ```diff
      //+kubebuilder:rbac:groups=cache.example.com,resources=memcacheds,verbs=get;list;watch;create;update;patch;delete
      //+kubebuilder:rbac:groups=cache.example.com,resources=memcacheds/status,verbs=get;update;patch
      //+kubebuilder:rbac:groups=cache.example.com,resources=memcacheds/finalizers,verbs=update
      //+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
    + //+kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;
    ```

1. Check
    1. Run the controller.
        ```bash
        make run
        ```
    1. Apply a `Memcached` (CR).
        ```bash
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Check logs.

        ```bash
        2021-12-10T13:09:03.716+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T13:09:03.716+0900    INFO    controller.memcached    2. Check if the deployment already exists, if not create a new one. Creating a new Deployment    {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "Deployment.Namespace": "default", "Deployment.Name": "memcached-sample"}
        2021-12-10T13:09:03.727+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T13:09:03.829+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:03.841+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:03.841+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T13:09:03.841+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:03.841+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:05.565+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T13:09:05.565+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:05.565+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:05.587+0900    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        2021-12-10T13:09:05.587+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        2021-12-10T13:09:05.588+0900    INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status       {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-6c765df685-f9jpl", "memcached-sample-6c765df685-cf725"]}
        ```

    1. Check `Deployment`.

        ```
        kubectl get deploy
        NAME               READY   UP-TO-DATE   AVAILABLE   AGE
        memcached-sample   2/2     2            2           115s
        ```

    1. Check `status` in `Memcached` object.

        ```bash
        kubectl get Memcached memcached-sample -o jsonpath='{.status}' | jq
        {
          "nodes": [
            "memcached-sample-6c765df685-9drvp",
            "memcached-sample-6c765df685-g7nl8"
          ]
        }
        ```

    1. Delete the CR.
        ```bash
        kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Stop the controller.


### 5. Deploy with `Deployment`.

1. Build docker image and push it to registry.

    ```
    export OPERATOR_IMG="nakamasato/memcached-operator:v0.0.1"
    make docker-build docker-push IMG=$OPERATOR_IMG
    ```

1. Deploy operator.

    ```
    make deploy IMG=$OPERATOR_IMG
    ```

1. Add CR.

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

1. Check controller's log.

    ```
    kubectl logs $(kubectl get po -n memcached-operator-system | grep memcached-operator-controller-manager | awk '{print $1}') -c manager -n memcached-operator-system -f
    ```

1. Delete CR.

    ```
    kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
    ```

1. Uninstall operator.

    ```
    make undeploy
    ```

### 6. Write controller tests

Tools to use:

1. [envtest](https://pkg.go.dev/sigs.k8s.io/controller-runtime/pkg/envtest) provides libraries for integration testing by starting a local control plane. (`etcd` an `kube-apiserver`)
1. [Ginkgo](https://pkg.go.dev/github.com/onsi/ginkgo) BDD framework.
1. [Gomega](https://pkg.go.dev/github.com/onsi/gomega) Matcher library for testing.

#### Prepare `suite_test.go`

1. Import necessary packages.
    ```diff
     import (
    +       "context"
            "path/filepath"
            "testing"
    +       ctrl "sigs.k8s.io/controller-runtime"
    +
            . "github.com/onsi/ginkgo"
            . "github.com/onsi/gomega"
            "k8s.io/client-go/kubernetes/scheme"
    -       "k8s.io/client-go/rest"
            "sigs.k8s.io/controller-runtime/pkg/client"
            "sigs.k8s.io/controller-runtime/pkg/envtest"
            "sigs.k8s.io/controller-runtime/pkg/envtest/ter"
            logf "sigs.k8s.io/controller-runtime/pkg/log"
            "sigs.k8s.io/controller-runtime/pkg/log/zap"
    +       "sigs.k8s.io/controller-runtime/pkg/manager"
    ```
1. Prepare global variables.
    ```diff
    -var cfg *rest.Config
    -var k8sClient client.Client
    -var testEnv *envtest.Environment
    +var (
    +       k8sClient  client.Client
    +       k8sManager manager.Manager
    +       testEnv    *envtest.Environment
    +       ctx        context.Context
    +       cancel     context.CancelFunc
    +)
    ```
1. Update `BeforeSuite`.
    1. Create context with cancel.
        ```go
        ctx, cancel = context.WithCancel(context.TODO())
        ```
    1. Register the schema to manager.
        ```go
        k8sManager, err = ctrl.NewManager(cfg, ctrl.Options{
    		Scheme: scheme.Scheme,
    	})
        ```
    1. Initialize `MemcachedReconciler` with the manager client schema.
        ```go
        err = (&MemcachedReconciler{
            Client: k8sManager.GetClient(),
            Scheme: k8sManager.GetScheme(),
        }).SetupWithManager(k8sManager)
        ```
    1. Start the with a goroutine.
        ```go
        go func() {
            defer GinkgoRecover()
            err = k8sManager.Start(ctx)
            Expect(err).ToNot(HaveOccurred(), "failed to run ger")
        }()
        ```
#### Write controller's tests in `controllers/memcached_controller_test.go`.

Test cases:
1. When `Memcached` is created
    1. `Deployment` should be created.
    1. `Memcached`'s nodes have pods' names.
1. When `Memcached`'s `size` is updated
    1. `Deployment`'s `replicas` should be updated.
    1. `Memcached`'s nodes have new pods' names.
1. When `Deployment` is updated
    1. Deleting `Deployment` -> `Deployment` is recreated.
    1. Updating `Deployment` with `replicas = 0` -> `Deployment`'s replicas is updated to the original number.

#### Run the tests

```
make test
```

### 7. Add CI

- `pre-commit`
- `reviewdog`
- `test`
