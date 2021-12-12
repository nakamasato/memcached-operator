# 6. Write controller tests

## Tools

1. [envtest](https://pkg.go.dev/sigs.k8s.io/controller-runtime/pkg/envtest) provides libraries for integration testing by starting a local control plane. (`etcd` an `kube-apiserver`)
1. [Ginkgo](https://pkg.go.dev/github.com/onsi/ginkgo) BDD framework.
1. [Gomega](https://pkg.go.dev/github.com/onsi/gomega) Matcher library for testing.

## Prepare `suite_test.go`

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
## Write controller's tests in `controllers/memcached_controller_test.go`.

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

## Run the tests

```
make test
```
