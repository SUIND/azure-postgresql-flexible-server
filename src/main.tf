resource "random_password" "master_password" {
  length  = 20
  special = false
}

resource "azurerm_resource_group" "main" {
  name     = var.md_metadata.name_prefix
  location = var.azure_virtual_network.specs.azure.region
  tags     = var.md_metadata.default_tags
}

resource "azurerm_private_dns_zone" "main" {
  name                = "${var.md_metadata.name_prefix}-dns.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.md_metadata.default_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = var.md_metadata.name_prefix
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = var.azure_virtual_network.data.infrastructure.id
  tags                  = var.md_metadata.default_tags
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                         = var.md_metadata.name_prefix
  resource_group_name          = azurerm_resource_group.main.name
  location                     = var.azure_virtual_network.specs.azure.region
  version                      = var.database.postgres_version
  backup_retention_days        = var.backup.backup_retention_days
  administrator_login          = var.database.username
  administrator_password       = random_password.master_password.result
  geo_redundant_backup_enabled = true
  storage_mb                   = var.database.storage_mb
  sku_name                     = var.database.sku_name
  tags                         = var.md_metadata.default_tags
  delegated_subnet_id          = var.database.allow_public_access ? null : azurerm_subnet.main.id
  private_dns_zone_id          = var.database.allow_public_access ? null : azurerm_private_dns_zone.main.id

  dynamic "high_availability" {
    for_each = var.database.high_availability ? toset(["enabled"]) : toset([])
    content {
      mode = "ZoneRedundant"
    }
  }

  lifecycle {
    ignore_changes = [
      zone,
      high_availability.0.standby_availability_zone
    ]
  }
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  count               = var.database.allow_public_access ? 1 : 0
  name                = "AllowAll"
  server_id           = azurerm_postgresql_flexible_server.main.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}