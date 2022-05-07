#!/bin/bash

set -eux

# 0. Clean up
echo "======== CLEAN UP ==========="

rm -rf api config controllers hack bin bundle 2> /dev/null
for f in .dockerignore .gitignore *.go go.* Makefile PROJECT Dockerfile bundle.Dockerfile; do
    if [ -f "$f" ] ; then
        rm $f
    fi
done

VERSIONS=$(operator-sdk version | sed 's/operator-sdk version: "\([v0-9\.]*\)".*kubernetes version: \"\([v0-9\.]*\)\".* go version: \"\(go[0-9\.]*\)\".*/operator-sdk: \1, kubernetes: \2, go: \3/g')
echo $VERSIONS
commit_message="Remove all files to upgrade versions ($VERSIONS)"
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
rm -rf docs mkdocs.yml Makefile.patch # need to make the dir clean before initializing a project
operator-sdk init --domain example.com --repo github.com/example/memcached-operator
echo "======== INIT PROJECT operator-sdk init completed =========="
echo "git checkout docs mkdocs.yml"
git checkout docs mkdocs.yml Makefile.patch
echo "git add & commit"
git add .
pre-commit run -a || true
git commit -am "1. Create a project"
echo "======== INIT PROJECT fix Makefile =========="

gsed -i '150,177d' Makefile # TODO: gnu-sed
gsed -i '149r Makefile.patch' Makefile # TODO: gnu-sed

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
MEMCACHED_CONTROLLER_GO_FILE=controllers/memcached_controller.go

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
EOF
# Add the contents before the last return in Reconcile function.
gsed -i $'/^\treturn ctrl.Result{}, nil/{e cat tmpfile\n}' $MEMCACHED_CONTROLLER_GO_FILE

cat << EOF > tmpfile

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
