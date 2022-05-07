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
git commit -am "4.1. Fetch Memcached instance."
