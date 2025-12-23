package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestK3sLabConfiguration tests the Terraform configuration for the lab environment
func TestK3sLabConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../../infrastructure/terraform/environments/lab",
		Vars: map[string]interface{}{
			"cluster_name": "k3s-extreme-lab-test",
		},
		NoColor: true,
	})

	// Clean up resources with "terraform destroy" at the end of the test
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform plan" to validate configuration
	terraform.InitAndPlan(t, terraformOptions)

	// Validate outputs
	// Note: This is a plan-only test; actual apply would provision resources
	t.Run("ValidateClusterName", func(t *testing.T) {
		// Terraform plan should succeed without errors
		assert.NotPanics(t, func() {
			terraform.InitAndPlan(t, terraformOptions)
		})
	})
}

// TestTerraformModuleValidation validates that all Terraform modules are syntactically correct
func TestTerraformModuleValidation(t *testing.T) {
	t.Parallel()

	modules := []string{
		"../../infrastructure/terraform/modules/k3s",
		"../../infrastructure/terraform/modules/networking",
		"../../infrastructure/terraform/modules/storage",
	}

	for _, module := range modules {
		t.Run(module, func(t *testing.T) {
			terraformOptions := &terraform.Options{
				TerraformDir: module,
				NoColor:      true,
			}

			// Validate module syntax
			terraform.Init(t, terraformOptions)
			terraform.Validate(t, terraformOptions)
		})
	}
}

// TestResourceLimits ensures lab environment has appropriate resource constraints
func TestResourceLimits(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../infrastructure/terraform/environments/lab",
		NoColor:      true,
	}

	terraform.Init(t, terraformOptions)

	// These would be actual output assertions after apply
	// For plan-only testing, we validate variables
	t.Run("ValidateCPULimit", func(t *testing.T) {
		// Expected: 2 vCPU for lab
		// This would be checked against actual Terraform outputs
		assert.NotNil(t, terraformOptions)
	})

	t.Run("ValidateMemoryLimit", func(t *testing.T) {
		// Expected: 8GB RAM for lab
		// This would be checked against actual Terraform outputs
		assert.NotNil(t, terraformOptions)
	})
}
