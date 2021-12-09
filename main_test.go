package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"testing"

	"github.com/riita10069/ket/pkg/setup"
	"k8s.io/apimachinery/pkg/types"
)

func TestMain(m *testing.M) {

	os.Exit(func() int {
		ctx := context.Background()
		ctx, cancel := context.WithCancel(ctx)
		defer cancel()

		fmt.Println("setup started.")

		cliSet, err := setup.Start(
			ctx,
			setup.WithBinaryDirectory("./_dev/bin"),
			setup.WithKubernetesVersion("1.20.2"),
			setup.WithKubeconfigPath("./.kubeconfig"),
			setup.WithUseSkaffold(),
			setup.WithSkaffoldVersion("1.35.0"),
			setup.WithSkaffoldYaml("./skaffold.yml"),
		)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to setup kind, kubectl and skaffold: %s\n", err)
			return 1
		}

		kubectl := cliSet.Kubectl
		_, err = kubectl.WaitAResource(
			ctx,
			"deploy",
			types.NamespacedName{
				Namespace: "memcached-operator-system",
				Name:      "memcached-operator-controller-manager",
			},
		)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to wait resource: %s\n", err)
			return 1
		}

		fmt.Println("setup done.")
		cancel() // teardown

		return m.Run()
	}())
}

func TestA(t *testing.T) {
    log.Println("TestA running")
}
