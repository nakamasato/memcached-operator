# 5. Write controller tests

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

1. Add the following lines at the end of `BeforeSuite` in `controllers/suite_test.go`.

    ```go
        // Create context with cancel.
        ctx, cancel = context.WithCancel(context.TODO())

        // Register the schema to manager.
        k8sManager, err = ctrl.NewManager(cfg, ctrl.Options{
            Scheme: scheme.Scheme,
        })

        // Initialize `MemcachedReconciler` with the manager client schema.
        err = (&MemcachedReconciler{
            Client: k8sManager.GetClient(),
            Scheme: k8sManager.GetScheme(),
        }).SetupWithManager(k8sManager)

        // Start the with a goroutine.
        go func() {
            defer GinkgoRecover()
            err = k8sManager.Start(ctx)
            Expect(err).ToNot(HaveOccurred(), "failed to run ger")
        }()
    ```

1. Add `cancel()` to AfterSuite.

    ```diff
     var _ = AfterSuite(func() {
    +       cancel()
            By("tearing down the test environment")
            err := testEnv.Stop()
            Expect(err).NotTo(HaveOccurred())
    ```

## Write controller's tests

Test cases in `controllers/memcached_controller_test.go`:
1. When `Memcached` is created
    1. `Deployment` should be created.
    1. `Memcached`'s nodes have pods' names.
1. When `Memcached`'s `size` is updated
    1. `Deployment`'s `replicas` should be updated.
    1. `Memcached`'s nodes have new pods' names.
1. When `Deployment` is updated
    1. Deleting `Deployment` -> `Deployment` is recreated.
    1. Updating `Deployment` with `replicas = 0` -> `Deployment`'s replicas is updated to the original number.

<details><summary>memcached_controller_test.go</summary>

```go
package controllers

import (
	"context"
	"fmt"
	"time"

	cachev1alpha1 "github.com/example/memcached-operator/api/v1alpha1"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	appsv1 "k8s.io/api/apps/v1"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"

	"sigs.k8s.io/controller-runtime/pkg/client"
)

const (
	memcachedApiVersion = "cache.example.com/v1alphav1"
	memcachedKind       = "Memcached"
	memcachedName       = "sample"
	memcachedNamespace  = "default"
	memcachedStartSize  = int32(3)
	memcachedUpdateSize = int32(10)
	timeout             = time.Second * 10
	interval            = time.Millisecond * 250
)

var _ = Describe("Memcached controller", func() {

	lookUpKey := types.NamespacedName{Name: memcachedName, Namespace: memcachedNamespace}

	AfterEach(func() {
		// Delete Memcached
		deleteMemcached(ctx, lookUpKey)
		// Delete all Pods
		deleteAllPods(ctx)
	})

	Context("When creating Memcached", func() {
		BeforeEach(func() {
			// Create Memcached
			createMemcached(ctx, memcachedStartSize)
		})
		It("Should create Deployment with the specified size and memcached image", func() {
			// Deployment is created
			deployment := &appsv1.Deployment{}
			Eventually(func() error {
				return k8sClient.Get(ctx, lookUpKey, deployment)
			}, timeout, interval).Should(Succeed())
			Expect(*deployment.Spec.Replicas).Should(Equal(memcachedStartSize))
			Expect(deployment.Spec.Template.Spec.Containers[0].Image).Should(Equal("memcached:1.4.36-alpine"))
			// https://github.com/kubernetes-sigs/controller-runtime/blob/master/pkg/controller/controllerutil/controllerutil_test.go
			Expect(deployment.OwnerReferences).ShouldNot(BeEmpty())
		})
		It("Should have pods name in Memcached Node", func() {
			checkIfDeploymentExists(ctx, lookUpKey)

			By("By creating Pods with labels")
			podNames := createPods(ctx, int(memcachedStartSize))

			updateMemcacheSize(ctx, lookUpKey, memcachedUpdateSize) // just to trigger reconcile

			checkMemcachedStatusNodes(ctx, lookUpKey, podNames)
		})
	})

	Context("When updating Memcached", func() {
		BeforeEach(func() {
			// Create Memcached
			createMemcached(ctx, memcachedStartSize)
			// Deployment is ready
			checkDeploymentReplicas(ctx, lookUpKey, memcachedStartSize)
		})

		It("Should update Deployment replicas", func() {
			By("Changing Memcached size")
			updateMemcacheSize(ctx, lookUpKey, memcachedUpdateSize)

			checkDeploymentReplicas(ctx, lookUpKey, memcachedUpdateSize)
		})

		It("Should update the Memcached status with the pod names", func() {
			By("Changing Memcached size")
			updateMemcacheSize(ctx, lookUpKey, memcachedUpdateSize)

			podNames := createPods(ctx, int(memcachedUpdateSize))
			checkMemcachedStatusNodes(ctx, lookUpKey, podNames)
		})
	})
	Context("When changing Deployment", func() {
		BeforeEach(func() {
			// Create Memcached
			createMemcached(ctx, memcachedStartSize)
			// Deployment is ready
			checkDeploymentReplicas(ctx, lookUpKey, memcachedStartSize)
		})

		It("Should check if the deployment already exists, if not create a new one", func() {
			By("Deleting Deployment")
			deployment := &appsv1.Deployment{}
			Expect(k8sClient.Get(ctx, lookUpKey, deployment)).Should(Succeed())
			Expect(k8sClient.Delete(ctx, deployment)).Should(Succeed())

			// Deployment will be recreated by the controller
			checkIfDeploymentExists(ctx, lookUpKey)
		})

		It("Should ensure the deployment size is the same as the spec", func() {
			By("Changing Deployment replicas")
			deployment := &appsv1.Deployment{}
			Expect(k8sClient.Get(ctx, lookUpKey, deployment)).Should(Succeed())
			*deployment.Spec.Replicas = 0
			Expect(k8sClient.Update(ctx, deployment)).Should(Succeed())

			// replicas will be updated back to the original one by the controller
			checkDeploymentReplicas(ctx, lookUpKey, memcachedStartSize)
		})
	})

	// Deployment is expected to be deleted when Memcached is deleted.
	// As it's garbage collector's responsibility, which is not part of envtest, we don't test it here.
})

func checkIfDeploymentExists(ctx context.Context, lookUpKey types.NamespacedName) {
	deployment := &appsv1.Deployment{}
	Eventually(func() error {
		return k8sClient.Get(ctx, lookUpKey, deployment)
	}, timeout, interval).Should(Succeed())
}

func checkDeploymentReplicas(ctx context.Context, lookUpKey types.NamespacedName, expectedSize int32) {
	Eventually(func() (int32, error) {
		deployment := &appsv1.Deployment{}
		err := k8sClient.Get(ctx, lookUpKey, deployment)
		if err != nil {
			return int32(0), err
		}
		return *deployment.Spec.Replicas, nil
	}, timeout, interval).Should(Equal(expectedSize))
}

func newMemcached(size int32) *cachev1alpha1.Memcached {
	return &cachev1alpha1.Memcached{
		TypeMeta: metav1.TypeMeta{
			APIVersion: memcachedApiVersion,
			Kind:       memcachedKind,
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      memcachedName,
			Namespace: memcachedNamespace,
		},
		Spec: cachev1alpha1.MemcachedSpec{
			Size: size,
		},
	}
}

func createMemcached(ctx context.Context, size int32) {
	memcached := newMemcached(size)
	Expect(k8sClient.Create(ctx, memcached)).Should(Succeed())
}

func updateMemcacheSize(ctx context.Context, lookUpKey types.NamespacedName, size int32) {
	memcached := &cachev1alpha1.Memcached{}
	Expect(k8sClient.Get(ctx, lookUpKey, memcached)).Should(Succeed())
	memcached.Spec.Size = size
	Expect(k8sClient.Update(ctx, memcached)).Should(Succeed())
}

func deleteMemcached(ctx context.Context, lookUpKey types.NamespacedName) {
	memcached := &cachev1alpha1.Memcached{}
	Expect(k8sClient.Get(ctx, lookUpKey, memcached)).Should(Succeed())
	Expect(k8sClient.Delete(ctx, memcached)).Should(Succeed())
}

func checkMemcachedStatusNodes(ctx context.Context, lookUpKey types.NamespacedName, podNames []string) {
	memcached := &cachev1alpha1.Memcached{}
	Eventually(func() ([]string, error) {
		err := k8sClient.Get(ctx, lookUpKey, memcached)
		if err != nil {
			return nil, err
		}
		return memcached.Status.Nodes, nil
	}, timeout, interval).Should(ConsistOf(podNames))
}

func createPods(ctx context.Context, num int) []string {
	podNames := []string{}
	for i := 0; i < num; i++ {
		podName := fmt.Sprintf("pod-%d", i)
		podNames = append(podNames, podName)
		pod := newPod(podName)
		Expect(k8sClient.Create(ctx, pod)).Should(Succeed())
	}
	return podNames
}

func deleteAllPods(ctx context.Context) {
	err := k8sClient.DeleteAllOf(ctx, &v1.Pod{}, client.InNamespace(memcachedNamespace))
	Expect(err).NotTo(HaveOccurred())
}

func newPod(name string) *v1.Pod {
	return &v1.Pod{
		TypeMeta: metav1.TypeMeta{
			Kind:       "Pod",
			APIVersion: "v1",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: memcachedNamespace,
			Labels: map[string]string{
				"app":          "memcached",
				"memcached_cr": memcachedName,
			},
		},
		Spec: v1.PodSpec{
			Containers: []v1.Container{
				{
					Name:  "memcached",
					Image: "memcached",
				},
			},
		},
		Status: v1.PodStatus{},
	}
}
```

</details>

## Run the tests

```
make test
```

<details>

```
/Users/nakamasato/repos/nakamasato/memcached-operator/bin/controller-gen rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=config/crd/bases
/Users/nakamasato/repos/nakamasato/memcached-operator/bin/controller-gen object:headerFile="hack/boilerplate.go.txt" paths="./..."
go fmt ./...
go vet ./...
GOBIN=/Users/nakamasato/repos/nakamasato/memcached-operator/bin go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest
KUBEBUILDER_ASSETS="/Users/nakamasato/Library/Application Support/io.kubebuilder.envtest/k8s/1.23.3-darwin-amd64" go test ./... -coverprofile cover.out
?       github.com/example/memcached-operator   [no test files]
?       github.com/example/memcached-operator/api/v1alpha1      [no test files]
ok      github.com/example/memcached-operator/controllers       18.284s coverage: 79.3% of statements
```

</details>
