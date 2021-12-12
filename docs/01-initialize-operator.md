# 1. Initialize an operator

```
operator-sdk init --domain example.com --repo github.com/example/memcached-operator
```

<details><summary>result</summary>

```
Writing kustomize manifests for you to edit...
Writing scaffold for you to edit...
Get controller runtime:
$ go get sigs.k8s.io/controller-runtime@v0.10.0
go: downloading sigs.k8s.io/controller-runtime v0.10.0
go: downloading k8s.io/utils v0.0.0-20210802155522-efc7438f0176
go: downloading k8s.io/component-base v0.22.1
go: downloading k8s.io/apiextensions-apiserver v0.22.1
Update dependencies:
$ go mod tidy
Next: define a resource with:
$ operator-sdk create api
```

</details>
