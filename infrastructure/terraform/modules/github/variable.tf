# ====================================================================================
# GitHub Actions Variables and Secrets Configuration
# ====================================================================================

variable "organization" {
  description = "The GitHub organization name where the repository is located."
  type        = string
}

variable "repository_name" {
  description = "The name of the GitHub repository associated with the project."
  type        = string
}

variable "global_variables" {
  description = "A map of global variables that are applicable across all environments in the repository."
  type        = map(string)
}

variable "global_secrets" {
  description = "A map of global secrets that are applicable across all environments in the repository. These values are sensitive and should be handled securely."
  type        = map(string)
}

variable "environments" {
  description = "A map of environments, each containing its own set of variables and secrets. This allows customization per environment (e.g., staging, production)."
  type = map(object({
    variables = map(string)
    secrets   = map(string)
  }))
}
