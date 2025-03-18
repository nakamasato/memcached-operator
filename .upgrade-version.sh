#!/bin/bash

set -eu

export KUSTOMIZE_VERSION=v5.4.1

pre-commit
get_latest_release() {
	limit=${2:-5}
	curl --silent "https://api.github.com/repos/$1/releases" | jq -r '.[].tag_name' | head -n $limit
}

# operator-sdk version
if [ $# -eq 0 ]; then
	echo "specify operator-sdk version"
	get_latest_release "operator-framework/operator-sdk"
	exit 1
fi

if [[ ! "$1" =~ ^v[0-9]+.[0-9]+.[0-9]+$ ]];then
	echo "operator-sdk version format '$1' is invalid"
	get_latest_release "operator-framework/operator-sdk"
	exit 1
fi

OPERATOR_SDK_VERSION=$1
echo "operator-sdk version: $OPERATOR_SDK_VERSION"

read -r -p "Are you to upgrade to operator-sdk version $OPERATOR_SDK_VERSION? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        echo "start upgrading"
        ;;
    *)
        exit 1
        ;;
esac

curl -sS -L -o operator-sdk https://github.com/operator-framework/operator-sdk/releases/download/${OPERATOR_SDK_VERSION}/operator-sdk_$(go env GOOS)_$(go env GOARCH)
chmod +x operator-sdk
sudo mv operator-sdk /usr/local/bin/

# 0. Clean up
echo "======== CLEAN UP ==========="

KEEP_FILES=(
    mkdocs.yml
    README.md
    renovate.json
)

sudo rm -rf bin
rm -rf api config internal cmd hack bin bundle test
for f in `ls` .dockerignore .gitignore; do
    if [[ ! " ${KEEP_FILES[*]} " =~ " ${f} " ]] && [ -f "$f" ]; then
        rm $f
    fi
done

SDK_VERSION_CLI_RESULT=$(operator-sdk version)
SDK_VERSION_FOR_COMMIT=$(echo ${SDK_VERSION_CLI_RESULT} | sed 's/operator-sdk version: "\([v0-9\.]*\)".*kubernetes version: \"\([v0-9\.]*\)\".* go version: \"\(go[0-9\.]*\)\".*/operator-sdk: \1, kubernetes: \2, go: \3/g')
SDK_VERSION=$(echo ${SDK_VERSION_CLI_RESULT} | sed 's/operator-sdk version: "\([v0-9\.]*\)".*/\1/g')
GO_VERSION_CLI_RESULT=$(go version)
GO_VERSION=$(echo ${GO_VERSION_CLI_RESULT} | sed 's/go version \(go[^\s]*\) [^\s]*/\1/')
echo "SDK_VERSION: $SDK_VERSION_FOR_COMMIT, GO_VERSION: $GO_VERSION_CLI_RESULT"
commit_message="Remove all files to upgrade versions ($SDK_VERSION_FOR_COMMIT)"
last_commit_message=$(git log -1 --pretty=%B)
if [ -n "$(git status --porcelain)" ]; then
    echo "there are changes";
    if [[ $commit_message = $last_commit_message ]]; then
        echo "duplicated commit -> amend"
        git add .
        pre-commit run -a || true
        git commit -a --amend --no-edit
    else
        echo "create a commit"
        git add .
        pre-commit run -a || true
        git commit -am "$commit_message"
    fi
else
  echo "no changes";
  echo "======== CLEAN UP COMPLETED ==========="
  exit 0
fi

echo "======== CLEAN UP COMPLETED ==========="

# 1. Init a project
echo "======== INIT PROJECT ==========="
rm -rf docs mkdocs.yml renovate.json # need to make the dir clean before initializing a project
operator-sdk init --domain example.com --repo github.com/example/memcached-operator
echo "======== INIT PROJECT operator-sdk init completed =========="
echo "git checkout docs mkdocs.yml"
git checkout docs mkdocs.yml renovate.json

echo "update readme and index.md"
# 0. Update README
for f in README.md docs/index.md; do
	gsed -i "s#\[operator-sdk\](https://github.com/operator-framework/operator-sdk):.*#[operator-sdk](https://github.com/operator-framework/operator-sdk): [${SDK_VERSION}](https://github.com/operator-framework/operator-sdk/releases/${SDK_VERSION})#g" $f
	gsed -i "s#\[go\](https://github.com/golang/go):.*#[go](https://github.com/golang/go): [${GO_VERSION}](https://github.com/golang/go/releases/${GO_VERSION})#g" $f
done
echo "git add & commit"
git add .
pre-commit run -a || true
git commit -am "1. Create a project"

echo "======== INIT PROJECT COMPLETED ==========="

# 2. Create API (resource and controller) for Memcached
operator-sdk create api --group cache --version v1alpha1 --kind Memcached --resource --controller
git add .
pre-commit run -a || true
git commit -am "2. Create API (resource and controller) for Memcached"

# 3. Define API
## MemcachedSpec
MEMCACHED_GO_TYPE_FILE=api/v1alpha1/memcached_types.go
gsed -i '/type MemcachedSpec struct {/,/}/d' $MEMCACHED_GO_TYPE_FILE
cat << EOF > tmpfile
type MemcachedSpec struct {
        //+kubebuilder:validation:Minimum=0
        // Size is the size of the memcached deployment
        Size int32 \`json:"size"\`
}
EOF
gsed -i "/MemcachedSpec defines/ r tmpfile" $MEMCACHED_GO_TYPE_FILE
rm tmpfile

## MemcachedStatus
gsed -i '/type MemcachedStatus struct {/,/}/d' $MEMCACHED_GO_TYPE_FILE
cat << EOF > tmpfile
type MemcachedStatus struct {
        // Nodes are the names of the memcached pods
        Nodes []string \`json:"nodes"\`
}
EOF
gsed -i "/MemcachedStatus defines/ r tmpfile" $MEMCACHED_GO_TYPE_FILE
rm tmpfile
## fmt
make fmt

## Update CRD and deepcopy
make generate manifests
## Update config/samples/cache_v1alpha1_memcached.yaml
gsed -i '/spec:/{n;s/.*/  size: 3/}' config/samples/cache_v1alpha1_memcached.yaml

git add .
pre-commit run -a || true
git commit -am "3. Define Memcached API (CRD)"

# 4. Implement the controller

## 4.1. Fetch Memcached instance.
MEMCACHED_CONTROLLER_GO_FILE=internal/controller/memcached_controller.go

gsed -i '/^import/a "k8s.io/apimachinery/pkg/api/errors"' $MEMCACHED_CONTROLLER_GO_FILE
gsed -i '/Reconcile(ctx context.Context, req ctrl.Request) /,/^}/d' $MEMCACHED_CONTROLLER_GO_FILE
cat << EOF > tmpfile
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
EOF
gsed -i "/pkg\/reconcile/ r tmpfile" $MEMCACHED_CONTROLLER_GO_FILE
rm tmpfile
make fmt

git add .
pre-commit run -a || true
git commit -am "4.1. Implement Controller - Fetch the Memcached instance"

## 4.2 Check if the deployment already exists, and create one if not exists.
gsed -i '/^import/a "k8s.io/apimachinery/pkg/types"' $MEMCACHED_CONTROLLER_GO_FILE
gsed -i '/^import/a appsv1 "k8s.io/api/apps/v1"' $MEMCACHED_CONTROLLER_GO_FILE
gsed -i '/^import/a corev1 "k8s.io/api/core/v1"' $MEMCACHED_CONTROLLER_GO_FILE
gsed -i '/^import/a metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"' $MEMCACHED_CONTROLLER_GO_FILE

cat << EOF > tmpfile

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
EOF
# Add the contents before the last return in Reconcile function.
gsed -i $'/^\treturn ctrl.Result{}, nil/{e cat tmpfile\n}' $MEMCACHED_CONTROLLER_GO_FILE

cat << EOF > tmpfile

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
    return dep, nil
}

// labelsForMemcached returns the labels for selecting the resources
// belonging to the given memcached CR name.
func labelsForMemcached(name string) map[string]string {
    return map[string]string{"app": "memcached", "memcached_cr": name}
}
EOF
cat tmpfile >> $MEMCACHED_CONTROLLER_GO_FILE
rm tmpfile

gsed -i '/kubebuilder:rbac:groups=cache.example.com,resources=memcacheds\/finalizers/a \/\/+kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete' $MEMCACHED_CONTROLLER_GO_FILE
gsed -i '/For(&cachev1alpha1.Memcached{})/a Owns(&appsv1.Deployment{}).' $MEMCACHED_CONTROLLER_GO_FILE
make fmt manifests

git add .
pre-commit run -a || true
git commit -am "4.2. Implement Controller - Check if the deployment already exists, and create one if not exists"

## 4.3 Ensure the deployment size is the same as the spec.

cat << EOF > tmpfile

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
EOF
# Add the contents before the last return in Reconcile function.
gsed -i $'/^\treturn ctrl.Result{}, nil/{e cat tmpfile\n}' $MEMCACHED_CONTROLLER_GO_FILE
rm tmpfile
make fmt
gsed -i '/spec:/{n;s/.*/  size: 2/}' config/samples/cache_v1alpha1_memcached.yaml

git add .
pre-commit run -a || true
git commit -am "4.3. Implement Controller - Ensure the deployment size is the same as the spec"

## 4.4 Update the Memcached status with the pod names.
gsed -i '/^import/a "reflect"' $MEMCACHED_CONTROLLER_GO_FILE
cat << EOF > tmpfile

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
EOF
# Add the contents before the last return in Reconcile function.
gsed -i $'/^\treturn ctrl.Result{}, nil/{e cat tmpfile\n}' $MEMCACHED_CONTROLLER_GO_FILE

cat << EOF > tmpfile

// getPodNames returns the pod names of the array of pods passed in
func getPodNames(pods []corev1.Pod) []string {
	podNames := make([]string, 0, len(pods))
    for _, pod := range pods {
            podNames = append(podNames, pod.Name)
    }
    return podNames
}
EOF
cat tmpfile >> $MEMCACHED_CONTROLLER_GO_FILE
gsed -i '/kubebuilder:rbac:groups=apps,resources=deployments,verbs=get/a \/\/+kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;' $MEMCACHED_CONTROLLER_GO_FILE
rm tmpfile
make fmt manifests

git add .
pre-commit run -a || true
git commit -am "4.4. Implement Controller - Update the Memcached status with the pod names"

# 5. Write a test
CONTROLLER_SUITE_TEST_GO_FILE=internal/controller/suite_test.go
gsed -i '/^import/a "context"' $CONTROLLER_SUITE_TEST_GO_FILE # add "context" to import
gsed -i '/^import/a ctrl "sigs.k8s.io/controller-runtime"' $CONTROLLER_SUITE_TEST_GO_FILE # add 'ctrl "sigs.k8s.io/controller-runtime"' to import
gsed -i '/^import/a "sigs.k8s.io/controller-runtime/pkg/manager"' $CONTROLLER_SUITE_TEST_GO_FILE # add "sigs.k8s.io/controller-runtime/pkg/manager" to import
# gsed -i '/"k8s.io\/client-go\/rest"/d' $CONTROLLER_SUITE_TEST_GO_FILE # remove "k8s.io/client-go/rest" from import
gsed -i '/^var [a-z]/d' $CONTROLLER_SUITE_TEST_GO_FILE # remove vars

cat << EOF > tmpfile
var (
       cfg        *rest.Config
       k8sClient  client.Client
       k8sManager manager.Manager
       testEnv    *envtest.Environment
       ctx        context.Context
       cancel     context.CancelFunc
)

EOF
gsed -i $'/^func TestControllers/{e cat tmpfile\n}' $CONTROLLER_SUITE_TEST_GO_FILE # add vars just before TestAPIs

cat << EOF > tmpfile

    // Create context with cancel.
    ctx, cancel = context.WithCancel(context.TODO())

    // Register the schema to manager.
    k8sManager, err = ctrl.NewManager(cfg, ctrl.Options{
        Scheme: scheme.Scheme,
    })
	Expect(err).NotTo(HaveOccurred())

    // Initialize \`MemcachedReconciler\` with the manager client schema.
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
EOF
gsed -i '/Expect(k8sClient).NotTo(BeNil())$/r tmpfile' $CONTROLLER_SUITE_TEST_GO_FILE # add the logic to initialize a manager, register controller and start the manager.
gsed -i '/^var _ = AfterSuite(func() {$/a cancel()' $CONTROLLER_SUITE_TEST_GO_FILE # add cancel() after the line "var _ = AfterSuite(func() {"
rm tmpfile
cat << EOF > internal/controller/memcached_controller_test.go
package controller

import (
	"context"
	"fmt"
	"time"

	cachev1alpha1 "github.com/example/memcached-operator/api/v1alpha1"
	. "github.com/onsi/ginkgo/v2"
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
EOF
make fmt
go mod tidy
make test

git add .
pre-commit run -a || true
git commit -am "5. Write controller test"


# 6.1. Deploy with Deployment
make kustomize
cd config/manager && ../../bin/kustomize edit set image controller=nakamasato/memcached-operator && cd -

git add .
pre-commit run -a || true
git commit -am "6.1. Deploy with Deployment"

# 6.2. Deploy with OLM
mkdir -p config/manifests/bases
cat << EOF > config/manifests/bases/memcached-operator.clusterserviceversion.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  annotations:
    alm-examples: '[]'
    capabilities: Basic Install
  name: memcached-operator.v0.0.0
  namespace: placeholder
spec:
  apiservicedefinitions: {}
  customresourcedefinitions:
    owned:
    - description: Memcached is the Schema for the memcacheds API
      displayName: Memcached
      kind: Memcached
      name: memcacheds.cache.example.com
      version: v1alpha1
  description: memcached-operator
  displayName: memcached-operator
  icon:
  - base64data: ""
    mediatype: ""
  install:
    spec:
      deployments: null
    strategy: ""
  installModes:
  - supported: false
    type: OwnNamespace
  - supported: false
    type: SingleNamespace
  - supported: false
    type: MultiNamespace
  - supported: true
    type: AllNamespaces
  keywords:
  - memcached
  links:
  - name: Memcached Operator
    url: https://memcached-operator.domain
  maintainers:
  - email: masatonaka1989@gmail.com
    name: naka
  maturity: alpha
  provider:
    name: naka
  version: 0.0.0
EOF

IMG=nakamasato/memcached-operator
make bundle
git add .
make lint-fix
pre-commit run -a || true
git commit -am "6.2. Deploy with OLM"
