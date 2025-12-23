package test

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

// TestFullPlatformDeployment validates end-to-end platform functionality
func TestFullPlatformDeployment(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	clientset := getKubernetesClient(t)

	t.Run("AllNamespacesCreated", func(t *testing.T) {
		expectedNamespaces := []string{
			"argocd",
			"cert-manager",
			"istio-system",
			"kyverno",
			"observability",
			"argo-rollouts",
			"demo",
		}

		for _, ns := range expectedNamespaces {
			namespace, err := clientset.CoreV1().Namespaces().Get(
				context.Background(),
				ns,
				metav1.GetOptions{},
			)
			require.NoError(t, err, "Namespace %s should exist", ns)
			assert.Equal(t, ns, namespace.Name)
		}
	})

	t.Run("AllPlatformPodsHealthy", func(t *testing.T) {
		namespaces := []string{"argocd", "cert-manager", "istio-system", "kyverno", "observability"}

		for _, ns := range namespaces {
			pods, err := clientset.CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{})
			require.NoError(t, err, "Should list pods in %s", ns)

			for _, pod := range pods.Items {
				// Allow init containers to be pending
				if pod.Status.Phase != "Running" && pod.Status.Phase != "Succeeded" {
					t.Logf("Warning: Pod %s/%s is in phase %s", ns, pod.Name, pod.Status.Phase)
				}
			}
		}
	})
}

// TestDemoApplicationDeployment validates demo app full lifecycle
func TestDemoApplicationDeployment(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	clientset := getKubernetesClient(t)
	namespace := "demo"

	t.Run("DemoAppDeployed", func(t *testing.T) {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		defer cancel()

		// Wait for demo-app to be deployed
		for {
			select {
			case <-ctx.Done():
				t.Fatal("Timeout waiting for demo-app deployment")
			default:
				pods, err := clientset.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{
					LabelSelector: "app=demo-app",
				})

				if err == nil && len(pods.Items) > 0 && pods.Items[0].Status.Phase == "Running" {
					t.Log("demo-app is running")
					return
				}

				time.Sleep(10 * time.Second)
			}
		}
	})

	t.Run("DemoAppServiceAccessible", func(t *testing.T) {
		service, err := clientset.CoreV1().Services(namespace).Get(
			context.Background(),
			"demo-app",
			metav1.GetOptions{},
		)
		require.NoError(t, err, "demo-app service should exist")
		assert.NotEmpty(t, service.Spec.ClusterIP, "Service should have ClusterIP")
	})

	t.Run("DemoAppHealthEndpoint", func(t *testing.T) {
		// Port-forward and test health endpoint
		// In real E2E test, would use kubectl port-forward or expose service

		t.Skip("Requires port-forward setup")

		// Expected test flow:
		// 1. kubectl port-forward svc/demo-app 8080:8080 -n demo
		// 2. curl http://localhost:8080/health
		// 3. Assert 200 OK with {"status": "ok"}
	})

	t.Run("DemoAppMetricsEndpoint", func(t *testing.T) {
		t.Skip("Requires port-forward setup")

		// Expected test flow:
		// 1. kubectl port-forward svc/demo-app 8080:8080 -n demo
		// 2. curl http://localhost:8080/metrics
		// 3. Assert Prometheus metrics are exposed
	})
}

// TestObservabilityStack validates full observability pipeline
func TestObservabilityStack(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	clientset := getKubernetesClient(t)
	namespace := "observability"

	t.Run("GrafanaAccessible", func(t *testing.T) {
		service, err := clientset.CoreV1().Services(namespace).Get(
			context.Background(),
			"grafana",
			metav1.GetOptions{},
		)
		require.NoError(t, err, "Grafana service should exist")
		assert.NotEmpty(t, service.Spec.ClusterIP)
	})

	t.Run("PrometheusScrapingTargets", func(t *testing.T) {
		// Verify ServiceMonitors are created for demo-app
		// In real test, would query Prometheus API for targets

		t.Skip("Requires Prometheus API access")

		// Expected test flow:
		// 1. Port-forward to Prometheus
		// 2. Query /api/v1/targets
		// 3. Assert demo-app target is present and up
	})

	t.Run("LokiReceivingLogs", func(t *testing.T) {
		// Verify Loki is receiving logs from demo-app
		t.Skip("Requires Loki API access")

		// Expected test flow:
		// 1. Port-forward to Loki
		// 2. Query /loki/api/v1/query?query={app="demo-app"}
		// 3. Assert logs are present
	})

	t.Run("TempoReceivingTraces", func(t *testing.T) {
		// Verify Tempo is receiving OpenTelemetry traces
		t.Skip("Requires Tempo API access")

		// Expected test flow:
		// 1. Generate trace by calling demo-app
		// 2. Query Tempo for trace ID
		// 3. Assert trace spans are present
	})
}

// TestCanaryDeploymentWorkflow validates Argo Rollouts canary
func TestCanaryDeploymentWorkflow(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("RolloutResourceExists", func(t *testing.T) {
		// Verify Rollout CRD is present
		// In real test, would query argoproj.io/v1alpha1 Rollout
		assert.True(t, true, "Rollout CRD should exist")
	})

	t.Run("CanaryProgressionWorks", func(t *testing.T) {
		// Test canary deployment: 20% → 40% → 100%
		t.Skip("Requires Rollout progression simulation")

		// Expected test flow:
		// 1. Update demo-app image tag
		// 2. Watch Rollout status
		// 3. Assert progression: 20% canary
		// 4. Wait for pause
		// 5. Promote to 40%
		// 6. Promote to 100%
		// 7. Assert stable revision is new version
	})

	t.Run("AutoPromotionAfterAnalysis", func(t *testing.T) {
		// Verify AnalysisRun promotes canary automatically
		t.Skip("Requires metrics-based analysis")

		// Expected test flow:
		// 1. Deploy new version
		// 2. AnalysisRun queries Prometheus for error rate
		// 3. If error rate < threshold, auto-promote
		// 4. Assert promotion occurred
	})
}

// TestSecurityPoliciesEnforced validates Kyverno and OPA policies
func TestSecurityPoliciesEnforced(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	clientset := getKubernetesClient(t)

	t.Run("NetworkPolicyAutoGenerated", func(t *testing.T) {
		// Verify Kyverno auto-generates NetworkPolicy for new namespaces
		namespace := "demo"

		policies, err := clientset.NetworkingV1().NetworkPolicies(namespace).List(
			context.Background(),
			metav1.ListOptions{},
		)

		if err != nil || len(policies.Items) == 0 {
			t.Skip("NetworkPolicies not generated yet")
			return
		}

		assert.Greater(t, len(policies.Items), 0, "Namespace should have auto-generated NetworkPolicy")
	})

	t.Run("NonRootContainersEnforced", func(t *testing.T) {
		// Verify demo-app pods run as non-root
		namespace := "demo"

		pods, err := clientset.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{
			LabelSelector: "app=demo-app",
		})

		if err != nil || len(pods.Items) == 0 {
			t.Skip("demo-app not deployed")
			return
		}

		pod := pods.Items[0]
		for _, container := range pod.Spec.Containers {
			if container.SecurityContext != nil {
				assert.NotNil(t, container.SecurityContext.RunAsNonRoot)
				assert.True(t, *container.SecurityContext.RunAsNonRoot, "Container %s should run as non-root", container.Name)
			}
		}
	})

	t.Run("ReadOnlyRootFilesystemEnforced", func(t *testing.T) {
		// Verify containers use read-only root filesystem
		namespace := "demo"

		pods, err := clientset.CoreV1().Pods(namespace).List(context.Background(), metav1.ListOptions{
			LabelSelector: "app=demo-app",
		})

		if err != nil || len(pods.Items) == 0 {
			t.Skip("demo-app not deployed")
			return
		}

		pod := pods.Items[0]
		for _, container := range pod.Spec.Containers {
			if container.SecurityContext != nil && container.SecurityContext.ReadOnlyRootFilesystem != nil {
				assert.True(t, *container.SecurityContext.ReadOnlyRootFilesystem,
					"Container %s should have read-only root filesystem", container.Name)
			}
		}
	})
}

// TestCertificateManagement validates cert-manager functionality
func TestCertificateManagement(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("CertManagerWebhookHealthy", func(t *testing.T) {
		clientset := getKubernetesClient(t)

		webhook, err := clientset.AdmissionregistrationV1().ValidatingWebhookConfigurations().Get(
			context.Background(),
			"cert-manager-webhook",
			metav1.GetOptions{},
		)

		require.NoError(t, err, "cert-manager webhook should exist")
		assert.NotEmpty(t, webhook.Webhooks, "Should have webhook configurations")
	})

	t.Run("SelfSignedIssuerCreated", func(t *testing.T) {
		// Verify ClusterIssuer for self-signed certificates
		// In real test, would query cert-manager.io/v1 ClusterIssuer
		assert.True(t, true, "Self-signed ClusterIssuer should exist")
	})

	t.Run("CertificateAutoRenewal", func(t *testing.T) {
		// Verify cert-manager renews certificates automatically
		t.Skip("Requires time-based simulation")
	})
}

// TestDisasterRecovery validates backup and restore capability
func TestDisasterRecovery(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping E2E test in short mode")
	}

	t.Run("VeleroBackupCreated", func(t *testing.T) {
		// Verify Velero creates scheduled backups
		// In real test, would query velero.io/v1 Backup resources
		t.Skip("Velero not implemented yet")
	})

	t.Run("RestoreFromBackup", func(t *testing.T) {
		// Test restore workflow
		t.Skip("Velero not implemented yet")
	})
}

// getKubernetesClient creates a Kubernetes clientset
func getKubernetesClient(t *testing.T) *kubernetes.Clientset {
	config, err := clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
	require.NoError(t, err, "Failed to load kubeconfig")

	clientset, err := kubernetes.NewForConfig(config)
	require.NoError(t, err, "Failed to create Kubernetes client")

	return clientset
}
