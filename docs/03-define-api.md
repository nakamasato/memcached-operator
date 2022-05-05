# 3. Define Memcached API (Custom Resource Definition)

1. Update [api/v1alpha1/memcached_types.go]()

    ```go
    // MemcachedSpec defines the desired state of Memcached
    type MemcachedSpec struct {
    	//+kubebuilder:validation:Minimum=0
    	// Size is the size of the memcached deployment
    	Size int32 `json:"size"`
    }

    // MemcachedStatus defines the observed state of Memcached
    type MemcachedStatus struct {
    	// Nodes are the names of the memcached pods
    	Nodes []string `json:"nodes"`
    }
    ```

1. `make generate` -> `controller-gen` to update [api/v1alpha1/zz_generated.deepcopy.go]()
1. `make manifests` -> Make CRD manifests
1. Update [config/samples/cache_v1alpha1_memcached.yaml]() with `size: 3`
