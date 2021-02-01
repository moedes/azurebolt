plan azure::tfdestroy (
  TargetSpec $targets
) {
    ##########################################################
    # Remove terraform resources that shouldn't be destroyed #
    ##########################################################

    run_command('cd terraform && terraform state rm azurerm_subnet.pe_subnet', $targets)
    run_command('cd terraform && terraform state rm azurerm_virtual_network.vnet', $targets)
    run_command('cd terraform && terraform state rm azurerm_resource_group.RG', $targets)

    # Get PE Server information from inventory
    $puppetserver = get_target('puppetserver')

    # Get Linux node(s) from inventory and purge from PE Server
    get_targets('linux').each | $target | {
      $purge = "puppet node purge ${target.name}.iiwtyyvgvfre1fq0t3cfwbyrpf.xx.internal.cloudapp.net"
      out::message($purge)
      run_command($purge, $puppetserver)
      # run_command("Remove-DNSServerResourceRecord -Zonename puppet.demo -Name ${target.name} -RRType A -RecordData ${target.uri} -Force", $dnsserver)
    }

    # Get Windows node(s) from inventory and remove from PE server
    get_targets('windows').each | $target | {
      $purge = "puppet node purge ${target.name}.iiwtyyvgvfre1fq0t3cfwbyrpf.xx.internal.cloudapp.net"
      out::message($purge)
      run_command($purge, $puppetserver)
      # run_command("Remove-DNSServerResourceRecord -Zonename puppet.demo -Name ${target.name} -RRType A -RecordData ${target.uri} -Force", $dnsserver)
    }

    # Terraform destory 
    run_plan('terraform::destroy', dir => '/Users/jerrymozes/code/pewazure/azurebolt/terraform')
}
