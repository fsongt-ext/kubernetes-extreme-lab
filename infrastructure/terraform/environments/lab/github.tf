locals {
  github = {
    organization = "fsongt-ext"
    repo = {
      "kubernetes-extreme-lab" = {
        global = {
          variables = {
            REGISTRY = module.acr.login_server
          }

          secrets = {
            ACR_USERNAME = module.acr.admin_username
            ACR_PASSWORD = module.acr.admin_password
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

  depends_on = [module.acr, module.keyvaults]
}
