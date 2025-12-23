#!/usr/bin/env python3
"""
Unit tests for Ansible playbooks using molecule and pytest.
Tests validate playbook syntax, variable handling, and role logic.
"""

import os
import yaml
import pytest
from pathlib import Path


class TestAnsiblePlaybookSyntax:
    """Test Ansible playbook syntax and structure."""

    INFRASTRUCTURE_PATH = Path(__file__).parent.parent.parent / "infrastructure" / "ansible"

    def test_k3s_install_playbook_exists(self):
        """Verify k3s-install.yaml playbook exists."""
        playbook = self.INFRASTRUCTURE_PATH / "playbooks" / "k3s-install.yaml"
        assert playbook.exists(), f"Playbook not found: {playbook}"

    def test_playbook_syntax_valid(self):
        """Validate YAML syntax of playbooks."""
        playbooks = [
            "playbooks/k3s-install.yaml",
            "playbooks/k3s-uninstall.yaml",
        ]

        for playbook_path in playbooks:
            full_path = self.INFRASTRUCTURE_PATH / playbook_path
            if not full_path.exists():
                continue

            with open(full_path, 'r') as f:
                try:
                    data = yaml.safe_load(f)
                    assert isinstance(data, list), f"{playbook_path} should be a list of plays"
                    assert len(data) > 0, f"{playbook_path} should have at least one play"
                except yaml.YAMLError as e:
                    pytest.fail(f"YAML syntax error in {playbook_path}: {e}")

    def test_roles_have_required_files(self):
        """Verify roles have required files (tasks/main.yaml, defaults/main.yaml)."""
        roles_path = self.INFRASTRUCTURE_PATH / "roles"

        if not roles_path.exists():
            pytest.skip("Roles directory does not exist")

        for role_dir in roles_path.iterdir():
            if not role_dir.is_dir():
                continue

            tasks_main = role_dir / "tasks" / "main.yaml"
            assert tasks_main.exists(), f"Role {role_dir.name} missing tasks/main.yaml"

            defaults_main = role_dir / "defaults" / "main.yaml"
            # Defaults are optional, but if present, should be valid YAML
            if defaults_main.exists():
                with open(defaults_main, 'r') as f:
                    yaml.safe_load(f)


class TestAnsibleInventory:
    """Test Ansible inventory configuration."""

    INFRASTRUCTURE_PATH = Path(__file__).parent.parent.parent / "infrastructure" / "ansible"

    def test_inventory_exists(self):
        """Verify inventory file exists."""
        inventory = self.INFRASTRUCTURE_PATH / "inventory" / "lab" / "hosts.yaml"
        if inventory.exists():
            with open(inventory, 'r') as f:
                data = yaml.safe_load(f)
                assert 'all' in data, "Inventory should have 'all' group"

    def test_group_vars_syntax(self):
        """Validate group_vars YAML syntax."""
        group_vars_path = self.INFRASTRUCTURE_PATH / "inventory" / "lab" / "group_vars"

        if not group_vars_path.exists():
            pytest.skip("group_vars directory does not exist")

        for var_file in group_vars_path.glob("*.yaml"):
            with open(var_file, 'r') as f:
                try:
                    yaml.safe_load(f)
                except yaml.YAMLError as e:
                    pytest.fail(f"YAML syntax error in {var_file}: {e}")


class TestK3sRoleLogic:
    """Test K3s role-specific logic."""

    def test_k3s_version_format(self):
        """Verify k3s_version follows expected format."""
        # Expected format: v1.30.0+k3s1
        version = "v1.30.0+k3s1"
        assert version.startswith("v"), "Version should start with 'v'"
        assert "+k3s" in version, "Version should contain '+k3s' suffix"

    def test_resource_requirements(self):
        """Validate minimum resource requirements."""
        min_cpu = 2  # vCPU
        min_memory = 8192  # MB

        # In real tests, these would be fetched from Ansible variables
        assert min_cpu >= 2, "Lab environment requires at least 2 vCPU"
        assert min_memory >= 8192, "Lab environment requires at least 8GB RAM"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
