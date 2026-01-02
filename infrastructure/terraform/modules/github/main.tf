resource "github_actions_variable" "this" {
  for_each = var.global_variables

  repository    = var.repository_name
  variable_name = each.key
  value         = each.value
}

resource "github_actions_secret" "this" {
  for_each = var.global_secrets

  repository      = var.repository_name
  secret_name     = each.key
  plaintext_value = each.value
}

resource "github_repository_environment" "this" {
  for_each = var.environments

  repository  = var.repository_name
  environment = each.key
}

resource "github_actions_environment_variable" "this" {
  for_each = merge([
    for env, env_data in var.environments : {
      for var_name, var_value in env_data.variables :
      "${env}_${var_name}" => {
        env   = env
        name  = var_name
        value = var_value
      }
    }
  ]...)

  repository    = var.repository_name
  variable_name = each.value.name
  value         = each.value.value
  environment   = each.value.env

  depends_on = [github_repository_environment.this]
}

resource "github_actions_environment_secret" "this" {
  for_each = merge([
    for env, env_data in var.environments : {
      for var_name, var_value in env_data.secrets :
      "${env}_${var_name}" => {
        env   = env
        name  = var_name
        value = var_value
      }
    }
  ]...)

  repository      = var.repository_name
  secret_name     = each.value.name
  plaintext_value = each.value.value
  environment     = each.value.env

  depends_on = [github_repository_environment.this]
}
