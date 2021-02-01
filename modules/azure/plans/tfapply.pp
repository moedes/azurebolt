plan azure::tfapply (
    TargetSpec $targets,
    String $subnet = lookup('subnet'),
    String $vnet = lookup('vnet'),
    String $resource_group = lookup('resource_group'),
    #String $challengepwd = undef,
){

  #####################
  # Terraform Actions #
  #####################

  # Initiatlize terraform
  run_task('terraform::initialize', $targets, 'dir' => '/Users/jerrymozes/code/pewazure/azurebolt/terraform')

  ########################################
  # Bring in existing resources in Azure #
  ########################################

  run_command("cd terraform && terraform import azurerm_subnet.pe_subnet ${subnet}", $targets)
  run_command("cd terraform && terraform import azurerm_resource_group.RG ${resource_group}", $targets)
  run_command("cd terraform && terraform import azurerm_virtual_network.vnet ${vnet}", $targets)

  #Run Terraform Apply
  run_plan('terraform::apply', 'dir' => '~/code/pewazure/azurebolt/terraform')
}
