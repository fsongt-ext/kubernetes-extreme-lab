locals {
  github = {
    organization = "fsongt-ext"
    repo = {
      "kubernetes-extreme-lab" = {
        global = {
          variables = {
            REGISTRY                 = module.acr.login_server
            HELM_STORAGE_ACCOUNT     = module.helm_storage.storage_account_name
            HELM_STORAGE_CONTAINER   = module.helm_storage.container_name
            HELM_REPO_URL            = module.helm_storage.helm_repo_url
          }

          secrets = {
            ACR_USERNAME     = module.acr.admin_username
            ACR_PASSWORD     = module.acr.admin_password
            HELM_STORAGE_KEY = module.helm_storage.primary_access_key
          }
        }

        envs = {}
      }
    }
  }
}

module "github" {
  source   = "../../modules/github"
  for_each = local.github.repo

  organization     = local.github.organization
  repository_name  = each.key
  global_variables = each.value.global.variables
  global_secrets   = each.value.global.secrets
  environments     = each.value.envs

  depends_on = [module.acr, module.keyvaults, module.helm_storage]
}
