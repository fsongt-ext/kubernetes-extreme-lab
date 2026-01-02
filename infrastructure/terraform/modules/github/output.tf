output "global_variables" {
  value = {
    for k, v in github_actions_variable.this :
    k => {
      variable_name = v.variable_name
      value         = v.value
    }
  }
  description = "Map of GitHub Actions global variables created."
}

output "global_secrets" {
  value = {
    for k, v in github_actions_secret.this :
    k => {
      secret_name     = v.secret_name
      plaintext_value = v.plaintext_value
    }
  }
  sensitive   = true
  description = "Map of GitHub Actions global secrets created."
}

output "environment_variables" {
  value = {
    for k, v in github_actions_environment_variable.this :
    k => {
      environment   = v.environment
      variable_name = v.variable_name
      value         = v.value
    }
  }
  description = "Map of GitHub Actions environment variables created."
}

output "environment_secrets" {
  value = {
    for k, v in github_actions_environment_secret.this :
    k => {
      environment     = v.environment
      secret_name     = v.secret_name
      plaintext_value = v.plaintext_value
    }
  }
  sensitive   = true
  description = "Map of GitHub Actions environment secrets created."
}
