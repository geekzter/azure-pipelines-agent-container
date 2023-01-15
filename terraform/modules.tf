module diagnostics_storage {
  source                       = "./modules/diagnostics-storage"

  location                     = var.location
  create_log_analytics_workspace = (var.log_analytics_workspace_resource_id != "" && var.log_analytics_workspace_resource_id != null) ? false : true
  create_files_share           = var.create_files_share
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
}

module network {
  source                       = "./modules/network"

  address_space                = var.address_space
  bastion_tags                 = var.bastion_tags
  deploy_bastion               = var.deploy_bastion
  diagnostics_storage_id       = module.diagnostics_storage.diagnostics_storage_id
  gateway_type                 = var.gateway_type
  location                     = var.location
  log_analytics_workspace_resource_id   = local.log_analytics_workspace_resource_id
  peer_network_has_gateway     = var.peer_network_has_gateway
  peer_network_id              = var.peer_network_id
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = local.tags

  count                        = var.deploy_network ? 1 : 0
}

module container_registry {
  source                       = "./modules/container-registry"

  agent_identity_principal_id  = local.agent_identity_principal_id
  configure_access_control     = var.configure_access_control
  container_image              = var.container_repository
  container_registry_id        = var.container_registry_id
  github_repo_access_token     = var.github_repo_access_token
  location                     = var.location
  log_analytics_workspace_resource_id   = local.log_analytics_workspace_resource_id
  resource_group_name          = azurerm_resource_group.rg.name
  suffix                       = local.suffix
  tags                         = local.tags
}

module container_app_agents {
  source                       = "./modules/container-app"

  container_registry_id        = module.container_registry.container_registry_id
  container_repository         = var.container_repository
  devops_url                   = var.devops_url
  devops_pat                   = var.devops_pat
  diagnostics_storage_share_key= module.diagnostics_storage.diagnostics_storage_key
  diagnostics_storage_share_name= module.diagnostics_storage.diagnostics_storage_name
  diagnostics_share_name       = module.diagnostics_storage.diagnostics_share_name
  environment_variables        = local.environment_variables
  # gateway_id                   = var.deploy_network ? module.network.0.gateway_id : null # Requires upcoming Premium SKU
  gateway_id                   = null
  location                     = var.location
  log_analytics_workspace_resource_id= local.log_analytics_workspace_resource_id
  pipeline_agent_cpu           = var.pipeline_agent_cpu
  pipeline_agent_memory        = var.pipeline_agent_memory
  pipeline_agent_number_max    = var.pipeline_agent_number_max
  pipeline_agent_number_min    = var.pipeline_agent_number_min
  pipeline_agent_pool_id       = var.pipeline_agent_pool_id
  pipeline_agent_pool_name     = var.pipeline_agent_pool_name
  pipeline_agent_run_once      = var.pipeline_agent_run_once
  pipeline_agent_version_id    = var.pipeline_agent_version_id
  resource_group_id            = azurerm_resource_group.rg.id
  resource_group_name          = azurerm_resource_group.rg.name
  subnet_id                    = var.deploy_network ? module.network.0.container_apps_environment_subnet_id : null
  suffix                       = local.suffix
  tags                         = local.tags
  user_assigned_identity_id    = local.agent_identity_resource_id

  depends_on                   = [
    module.container_registry,
    module.network
  ]

  count                        = var.deploy_container_app ? 1 : 0
}

module aks_agents {
  source                       = "./modules/aks"

  admin_username               = "aksadmin"
  client_object_id             = data.azurerm_client_config.default.object_id
  configure_access_control     = var.configure_access_control
  dns_prefix                   = var.resource_prefix
  enable_node_public_ip        = !var.deploy_network || var.gateway_type == "None"
  location                     = var.location
  kube_config_path             = local.kube_config_absolute_path
  kubernetes_version           = var.kubernetes_version
  log_analytics_workspace_id   = local.log_analytics_workspace_resource_id
  network_outbound_type        = var.deploy_network ? (var.gateway_type == "Firewall" ? "userDefinedRouting" : (var.gateway_type == "NATGateway" ? "userAssignedNATGateway" : null)) : null
  network_plugin               = var.deploy_network ? "azure" : "kubenet"
  network_policy               = var.deploy_network ? "azure" : "calico"
  node_size                    = var.kubernetes_node_size
  peer_network_id              = var.peer_network_id
  node_subnet_id               = var.deploy_network ? module.network.0.aks_node_pool_subnet_id : null
  node_min_count               = var.kubernetes_node_min_count
  node_max_count               = var.kubernetes_node_max_count
  private_cluster_enabled      = var.aks_private_cluster_enabled
  resource_group_id            = azurerm_resource_group.rg.id
  tags                         = azurerm_resource_group.rg.tags
  user_assigned_identity_id    = local.agent_identity_resource_id
  user_assigned_identity_is_precreated=local.agent_identity_is_precreated

  count                        = var.deploy_aks ? 1 : 0
  depends_on                   = [module.network]
}