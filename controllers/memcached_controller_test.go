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

	"k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
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

	ctx := context.Background()
	lookUpKey := types.NamespacedName{Name: memcachedName, Namespace: memcachedNamespace}
	var stopFunc func()

	BeforeEach(func() {
		k8sManager, err := ctrl.NewManager(cfg, ctrl.Options{
			Scheme: scheme.Scheme,
		})
		Expect(err).ToNot(HaveOccurred())

		err = (&MemcachedReconciler{
			Client: k8sManager.GetClient(),
			Log:    ctrl.Log.WithName("controllers").WithName("Memcached"),
			Scheme: k8sManager.GetScheme(),
		}).SetupWithManager(k8sManager)
		Expect(err).ToNot(HaveOccurred())

		ctx, cancel := context.WithCancel(ctx)
		stopFunc = cancel
		go func() {
			err = k8sManager.Start(ctx)
			Expect(err).ToNot(HaveOccurred())
		}()
		time.Sleep(100 * time.Millisecond)
	})

	AfterEach(func() {
		stopFunc()
		time.Sleep(100 * time.Millisecond)
	})

	Context("When creating Memcached", func() {
		AfterEach(func() {
			memcached := &cachev1alpha1.Memcached{}
			Expect(k8sClient.Get(ctx, lookUpKey, memcached)).Should(Succeed())
			Expect(k8sClient.Delete(ctx, memcached)).Should(Succeed())
		})
		It("Should create Deployment with the specified size and memcached image", func() {
			By("By creating a new Memcached")
			memcached := newMemcached()
			Expect(k8sClient.Create(ctx, memcached)).Should(Succeed())
			deployment := &appsv1.Deployment{}
			Eventually(func() bool {
				err := k8sClient.Get(ctx, lookUpKey, deployment)
				return err == nil
			}, timeout, interval).Should(BeTrue())
			Expect(*deployment.Spec.Replicas).Should(Equal(memcachedStartSize))
			Expect(deployment.Spec.Template.Spec.Containers[0].Image).Should(Equal("memcached:1.4.36-alpine"))
		})
		It("Should have pods name in Memcached Node", func() {
			By("By creating a new Memcached")
			memcached := newMemcached()
			Expect(k8sClient.Create(ctx, memcached)).Should(Succeed())

			deployment := &appsv1.Deployment{}
			Eventually(func() bool {
				err := k8sClient.Get(ctx, lookUpKey, deployment)
				return err == nil
			}, timeout, interval).Should(BeTrue())

			// as envtest (kube-apiserver & etcd) doesn't create replicaset nor pods,
			// manually create pods with labels
			By("By creating Pods with labels")
			podNames := createPods(ctx, 3)

			// By("By triggering reconciliation logic") I thought I need to trigger reconciliation loop but not necessary why?
			// deployment.SetAnnotations(map[string]string{
			// 	"test": "test",
			// })
			// Expect(k8sClient.Update(ctx, deployment)).Should(Succeed())

			checkMemcachedStatusNodes(ctx, lookUpKey, podNames)
		})
	})

	Context("When updating Memcached", func() {
		var memcached *cachev1alpha1.Memcached
		var deployment *appsv1.Deployment
		AfterEach(func() {
			// delete Memcached
			memcached = &cachev1alpha1.Memcached{}
			Expect(k8sClient.Get(ctx, lookUpKey, memcached)).Should(Succeed())
			Expect(k8sClient.Delete(ctx, memcached)).Should(Succeed())

			// delete Deployment
			deployment = &appsv1.Deployment{}
			Expect(k8sClient.Get(ctx, lookUpKey, deployment)).Should(Succeed())
			Expect(k8sClient.Delete(ctx, deployment)).Should(Succeed())

			// delete all Pods
			err := k8sClient.DeleteAllOf(ctx, &v1.Pod{}, client.InNamespace(memcachedNamespace))
			Expect(err).NotTo(HaveOccurred())
		})
		BeforeEach(func() {
			// create Memcached
			memcached = newMemcached()
			memcached.Spec.Size = memcachedStartSize
			Expect(k8sClient.Create(ctx, memcached)).Should(Succeed())
			// Deployment is ready
			deployment := &appsv1.Deployment{}
			Eventually(func() bool {
				err := k8sClient.Get(ctx, lookUpKey, deployment)
				return err == nil
			}, timeout, interval).Should(BeTrue())
			Expect(*deployment.Spec.Replicas).Should(Equal(memcachedStartSize))
		})
		It("Should update Deployment replicas", func() {
			By("Changing Memcached size")
			memcached.Spec.Size = memcachedUpdateSize
			Expect(k8sClient.Update(ctx, memcached)).Should(Succeed())

			Eventually(func() (int32, error) {
				deployment := &appsv1.Deployment{}
				err := k8sClient.Get(ctx, lookUpKey, deployment)
				if err != nil {
					return int32(0), err
				}
				return *deployment.Spec.Replicas, nil
			}, timeout, interval).Should(Equal(memcachedUpdateSize))
		})
		It("Should update Memcached.Status.Node", func() {
			By("Changing Memcached size")
			Expect(k8sClient.Get(ctx, lookUpKey, memcached)).Should(Succeed())
			memcached.Spec.Size = memcachedUpdateSize
			Expect(k8sClient.Update(ctx, memcached)).Should(Succeed())

			podNames := createPods(ctx, int(memcachedUpdateSize))

			checkMemcachedStatusNodes(ctx, lookUpKey, podNames)
		})
	})
})

// func newReplicaSet() *appsv1.ReplicaSet {
// 	return &appsv1.ReplicaSet{
// 		TypeMeta: metav1.TypeMeta{
// 			Kind:       "ReplicaSet",
// 			APIVersion: "apps/v1",
// 		},
// 		ObjectMeta: metav1.ObjectMeta{
// 			Name:            memcachedName,
// 			GenerateName:    "",
// 			Namespace:       memcachedNamespace,
// 			SelfLink:        "",
// 			UID:             "",
// 			ResourceVersion: "",
// 			Generation:      0,
// 			CreationTimestamp: metav1.Time{
// 				Time: time.Time{},
// 			},
// 			DeletionTimestamp:          &metav1.Time{},
// 			DeletionGracePeriodSeconds: new(int64),
// 			Labels:                     map[string]string{},
// 			Annotations:                map[string]string{},
// 			OwnerReferences:            []metav1.OwnerReference{},
// 			Finalizers:                 []string{},
// 			ClusterName:                "",
// 			ManagedFields:              []metav1.ManagedFieldsEntry{},
// 		},
// 		Spec:   appsv1.ReplicaSetSpec{},
// 		Status: appsv1.ReplicaSetStatus{},
// 	}
// }

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

func newMemcached() *cachev1alpha1.Memcached {
	return &cachev1alpha1.Memcached{
		TypeMeta:   metav1.TypeMeta{APIVersion: memcachedApiVersion, Kind: memcachedKind},
		ObjectMeta: metav1.ObjectMeta{Name: memcachedName, Namespace: memcachedNamespace},
		Spec:       cachev1alpha1.MemcachedSpec{Size: memcachedStartSize},
	}
}
