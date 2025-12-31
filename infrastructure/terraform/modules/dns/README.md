# Azure DNS Module

This module creates and manages an Azure DNS zone with support for A, CNAME, and TXT records.

## Features

- **DNS Zone Management**: Creates an Azure DNS hosted zone for your domain
- **A Records**: Map domain names to IP addresses
- **CNAME Records**: Create aliases for domain names
- **TXT Records**: Add text records for verification, SPF, DKIM, etc.
- **Flexible Configuration**: Easy to add, modify, or remove DNS records

## Usage

```hcl
module "dns" {
  source = "../../modules/dns"

  domain_name         = "example.com"
  resource_group_name = azurerm_resource_group.main.name

  # A Records - Point to IP addresses
  a_records = {
    "auth" = {
      ttl     = 300
      records = ["1.2.3.4"]
    }
    "@" = {
      ttl     = 300
      records = ["1.2.3.4"]
    }
  }

  # CNAME Records - Create aliases
  cname_records = {
    "www" = {
      ttl    = 300
      record = "example.com"
    }
  }

  # TXT Records - For verification, SPF, etc.
  txt_records = {
    "@" = {
      ttl     = 300
      records = ["v=spf1 include:_spf.google.com ~all"]
    }
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain_name | The domain name for the DNS zone | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| a_records | Map of A records to create | `map(object)` | `{}` | no |
| cname_records | Map of CNAME records to create | `map(object)` | `{}` | no |
| txt_records | Map of TXT records to create | `map(object)` | `{}` | no |
| tags | Tags to apply to DNS resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| dns_zone_id | The ID of the DNS zone |
| dns_zone_name | The name of the DNS zone |
| name_servers | The name servers for the DNS zone (configure these at your domain registrar) |
| a_record_fqdns | Map of A record names to their FQDNs |
| cname_record_fqdns | Map of CNAME record names to their FQDNs |

## Post-Deployment Steps

After creating the DNS zone, you need to update your domain registrar with the Azure name servers:

1. Run `terraform output dns_name_servers` to get the name servers
2. Log in to your domain registrar (e.g., GoDaddy, Namecheap, Google Domains)
3. Update the name servers for your domain to use the Azure name servers
4. Wait for DNS propagation (can take up to 48 hours, usually much faster)

## Examples

### Basic DNS Zone with A Record

```hcl
module "dns" {
  source = "../../modules/dns"

  domain_name         = "example.com"
  resource_group_name = azurerm_resource_group.main.name

  a_records = {
    "@" = {
      ttl     = 300
      records = ["1.2.3.4"]
    }
  }
}
```

### DNS Zone with Multiple Record Types

```hcl
module "dns" {
  source = "../../modules/dns"

  domain_name         = "example.com"
  resource_group_name = azurerm_resource_group.main.name

  a_records = {
    "@" = {
      ttl     = 300
      records = ["1.2.3.4"]
    }
    "api" = {
      ttl     = 300
      records = ["5.6.7.8"]
    }
  }

  cname_records = {
    "www" = {
      ttl    = 300
      record = "example.com"
    }
  }

  txt_records = {
    "@" = {
      ttl     = 300
      records = [
        "v=spf1 include:_spf.google.com ~all",
        "google-site-verification=abc123"
      ]
    }
  }
}
```

## Notes

- The `@` symbol represents the root domain
- TTL (Time To Live) is in seconds (300 = 5 minutes)
- DNS changes may take time to propagate globally
- Always verify DNS records after creation using `nslookup` or `dig`
