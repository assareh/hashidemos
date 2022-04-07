# hashidemos-vault

This needs to be its own repo because of terraform issue [2430](https://github.com/hashicorp/terraform/issues/2430).

```
Terraform v1.1.6
on linux_amd64
Initializing plugins and modules...
╷
│ Error: no vault token found
│
│   with provider["registry.terraform.io/hashicorp/vault"],
│   on main.tf line 228, in provider "vault":
│  228: provider "vault" {
│
╵
Operation failed: failed running terraform plan (exit 1)

------------------------------------------------------------------------
```