package controllers

import (
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	cachev1alpha1 "github.com/example/memcached-operator/api/v1alpha1"
	appsv1 "k8s.io/api/apps/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

const (
	memcachedApiVersion = "cache.example.com/v1alphav1"
	memcachedKind       = "Memcached"
	memcachedName       = "memcached-sample"
	memcachedNamespace  = "default"
	timeout             = time.Second * 10
	interval            = time.Millisecond * 250
)

var _ = Describe("MemcachedController", func() {
	BeforeEach(func() {
		// Clean up Memcached
		memcached := &cachev1alpha1.Memcached{}
		err := k8sClient.Get(ctx,
			types.NamespacedName{
				Name:      memcachedName,
				Namespace: memcachedNamespace,
			},
			memcached,
		)
		if err == nil {
			err := k8sClient.Delete(ctx, memcached)
			Expect(err).NotTo(HaveOccurred())
		}
		// Clean up Deployment
		deployment := &appsv1.Deployment{}
		err = k8sClient.Get(ctx,
			types.NamespacedName{
				Name:      memcachedName,
				Namespace: memcachedNamespace,
			},
			deployment,
		)
		if err == nil {
			err := k8sClient.Delete(ctx, deployment)
			Expect(err).NotTo(HaveOccurred())
		}
	})
	Context("When Memcached is created", func() {
		It("Deployment should be created", func() {
			// Create Memcached
			memcached := &cachev1alpha1.Memcached{
				TypeMeta: metav1.TypeMeta{
					APIVersion: memcachedApiVersion,
					Kind:       memcachedKind,
				},
				ObjectMeta: metav1.ObjectMeta{
					Name:      memcachedName,
					Namespace: memcachedNamespace,
				},
				Spec: cachev1alpha1.MemcachedSpec{
					Size: 3,
				},
			}
			err := k8sClient.Create(ctx, memcached)
			Expect(err).ToNot(HaveOccurred())
			// Get Deployment by the memcached's name and namespace
			deployment := &appsv1.Deployment{}

			// Expect error to be nil
			Eventually(func() error {
				return k8sClient.Get(
					ctx,
					types.NamespacedName{
						Name:      memcachedName,
						Namespace: memcachedNamespace,
					},
					deployment,
				)
			}, timeout, interval).Should(BeNil())

			// Expect Deployment'replicas to be 3
			Eventually(func() int {
				err := k8sClient.Get(
					ctx,
					types.NamespacedName{
						Name:      memcachedName,
						Namespace: memcachedNamespace,
					},
					deployment,
				)
				if err != nil {
					return 0
				}
				return int(*deployment.Spec.Replicas)
			}, timeout, interval).Should(Equal(3))
		})
	})

	Context("When Memcached's size is updated", func() {
		It("Deployment's replica should be updated", func() {
			// Create Memcached with size 3
			memcached := &cachev1alpha1.Memcached{
				TypeMeta: metav1.TypeMeta{
					APIVersion: memcachedApiVersion,
					Kind:       memcachedKind,
				},
				ObjectMeta: metav1.ObjectMeta{
					Name:      memcachedName,
					Namespace: memcachedNamespace,
				},
				Spec: cachev1alpha1.MemcachedSpec{
					Size: 3,
				},
			}
			err := k8sClient.Create(ctx, memcached)
			Expect(err).ToNot(HaveOccurred())

			deployment := &appsv1.Deployment{}
			Eventually(func() int {
				err := k8sClient.Get(
					ctx,
					types.NamespacedName{
						Name:      memcachedName,
						Namespace: memcachedNamespace,
					},
					deployment,
				)
				if err != nil {
					return 0
				}
				return int(*deployment.Spec.Replicas)
			}, timeout, interval).Should(Equal(3))
			// Update Memcached's size with 2
			memcached.Spec.Size = 2
			err = k8sClient.Update(ctx, memcached)
			Expect(err).NotTo(HaveOccurred())

			// Get Deployment by the memcached's name and namespace
			// Expect replicas to be 2
			Eventually(func() int {
				err := k8sClient.Get(
					ctx,
					types.NamespacedName{
						Name:      memcachedName,
						Namespace: memcachedNamespace,
					},
					deployment,
				)
				if err != nil {
					return 0
				}
				return int(*deployment.Spec.Replicas)
			}, timeout, interval).Should(Equal(2))
		})
	})
})
