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
