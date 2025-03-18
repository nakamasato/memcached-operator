# 4. Implement the controller
## 4.1. Fetch Memcached instance.

1. Write the following lines in `Reconcile` function in [internal/controller/memcached_controller.go]() and import the necessary package.

    ```go
    import (
        "k8s.io/apimachinery/pkg/api/errors"
        // ...
    )
    ```

    ```go
    func (r *MemcachedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    	log := log.FromContext(ctx)

    	// 1. Fetch the Memcached instance
    	memcached := &cachev1alpha1.Memcached{}
    	err := r.Get(ctx, req.NamespacedName, memcached)
    	if err != nil {
    		if errors.IsNotFound(err) {
    			log.Info("1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted")
    			return ctrl.Result{}, nil
    		}
    		// Error reading the object - requeue the request.
    		log.Error(err, "1. Fetch the Memcached instance. Failed to get Mmecached")
    		return ctrl.Result{}, err
    	}
    	log.Info("1. Fetch the Memcached instance. Memchached resource found", "memcached.Name", memcached.Name, "memcached.Namespace", memcached.Namespace)
    	return ctrl.Result{}, nil
    }
    ```

1. Check
    1. Run the controller.
        ```bash
        make run # if you haven't installed the CRD, you need to run `make install` before running `make run`
        ```
    1. Apply a `Memcached` (CR).
        ```bash
        kubectl apply -f config/samples/cache_v1alpha1_memcached.yaml
        ```
    1. Check logs.

        ```bash
        1.651712191392899e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        ```

    1. Delete the CR.
        ```bash
        kubectl delete -f config/samples/cache_v1alpha1_memcached.yaml
        ```

    1. Check logs.
        ```bash
        1.6517122291298392e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted    {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        ```
    1. Stop the controller. `ctrl-c`

## 4.2 Check if the deployment already exists, and create one if not exists.

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
            dep, err := r.deploymentForMemcached(memcached)
            if err != nil {
                log.Error(err, "2. Check if the deployment already exists, if not create a new one. Failed to create new Deployment", "memcached.Namespace", memcached.Namespace, "memcached.Name", memcached.Name)
                return ctrl.Result{}, err
            }
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

    1. Initialize `appv1.Deployment`
    1. Set the replica size to `m.Spec.Size` (from `Memcached` custom resource)
    1. Set owner references `ctrl.SetControllerReference(m, dep, r.Scheme)`

    <details><summary>deploymentForMemcached</summary>

    ```go
    // deploymentForMemcached returns a memcached Deployment object
    func (r *MemcachedReconciler) deploymentForMemcached(m *cachev1alpha1.Memcached) (*appsv1.Deployment, error) {
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
        err := ctrl.SetControllerReference(m, dep, r.Scheme)
        if err != nil {
            return nil, err
        }
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

    func (r *MemcachedReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
        // ...
    }
    ```

    Run `make manifests` to update `config/rbac/role.yaml`.

    <details><summary>diff</summary>

    ```diff
    --- a/config/rbac/role.yaml
    +++ b/config/rbac/role.yaml
    @@ -5,6 +5,18 @@ metadata:
       creationTimestamp: null
       name: manager-role
     rules:
    +- apiGroups:
    +  - apps
    +  resources:
    +  - deployments
    +  verbs:
    +  - create
    +  - delete
    +  - get
    +  - list
    +  - patch
    +  - update
    +  - watch
    ```

    </details>

1. Add `Owns(&appsv1.Deployment{})` to the controller manager.

    ```diff
     // SetupWithManager sets up the controller with the Manager.
     func (r *MemcachedReconciler) SetupWithManager(mgr ctrl.Manager) error {
         return ctrl.NewControllerManagedBy(mgr).
             For(&cachev1alpha1.Memcached{}).
    +        Owns(&appsv1.Deployment{}). // To capture changes of the Deployments owned by this controller
             Complete(r)
     }
    ```

    - `For` specifies the first resource to watch.
    - `Owns` specifies the secondary resource to watch. Only capture changes of the Deployments owned by this controller.

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
        1.651716003245384e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716003245449e+09   INFO    controller.memcached    2. Check if the deployment already exists, if not create a new one. Creating a new Deployment   {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "Deployment.Namespace": "default", "Deployment.Name": "memcached-sample"}
        1.651716003421142e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716003426686e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.65171600352492e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716004351556e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.6517160069085371e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716020319972e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716021237856e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716025396706e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        ```

        There are 10 lines of logs:
        1. When `Memcached` object is created.
        1. Create `Deployment`.
        1. Requeued event
        1. `Deployment` creation event and more events are created accordingly. (`Owns`)

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
        1.651716313736277e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted    {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        1.65171631389033e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted    {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        ```
    1. Check `Deployment`.
        ```
        kubectl get deploy
        No resources found in default namespace.
        ```
    1. Stop the controller. `ctrl-c`

## 4.3 Ensure the deployment size is the same as the spec.

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
        1.6517166666855512e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716666815873e+09   INFO    controller.memcached    3. Ensure the deployment size is the same as the spec. Update deployment size   {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "Deployment.Spec.Replicas": 2}
        1.651716666815955e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651716666821547e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.65171666694696e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.65171666713287e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
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
        1.65171673062515e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted    {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        1.65171673093264e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memcached resource not found. Ignoring since object must be deleted    {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default"}
        ```
    1. Check `Deployment`.
        ```
        kubectl get deploy
        No resources found in default namespace.
        ```
    1. Stop the controller. `ctrl-c`


## 4.4 Update the Memcached status with the pod names.

1. Add `"reflect"` to `import`.
    ```go
    import (
	    "reflect"
        // ...
    )
    ```

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

    Run the following command to update `config/rbac/role.yaml`:

    ```
    make manifests
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
        1.6517855025391748e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.6517855025392709e+09  INFO    controller.memcached    2. Check if the deployment already exists, if not create a new one. Creating a new Deployment   {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "Deployment.Namespace": "default", "Deployment.Name": "memcached-sample"}
        1.6517855026461499e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651785502847106e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": []}
        1.651785502847143e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": []}
        1.651785502847202e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651785502847241e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": []}
        1.651785502848351e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": []}
        1.651785502891124e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.6517855028911989e+09  INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": []}
        1.651785502891249e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": []}
        1.651785502954266e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.6517855029543822e+09  INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.651785503020395e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.6517855030236201e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651785503023705e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.6517855030237281e+09  INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.6517855031085582e+09  INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651785503108638e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.651785503108653e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.65178550697348e+09    INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651785506973621e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.6517855069736378e+09  INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.651785507024296e+09   INFO    controller.memcached    1. Fetch the Memcached instance. Memchached resource found      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Name": "memcached-sample", "memcached.Namespace": "default"}
        1.651785507024448e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Pod list     {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "podNames": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
        1.651785507024466e+09   INFO    controller.memcached    4. Update the Memcached status with the pod names. Update memcached.Status      {"reconciler group": "cache.example.com", "reconciler kind": "Memcached", "name": "memcached-sample", "namespace": "default", "memcached.Status.Nodes": ["memcached-sample-5c8cffd96c-wjqsd", "memcached-sample-5c8cffd96c-5pthm"]}
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

    1. Stop the controller. `ctrl-c`
