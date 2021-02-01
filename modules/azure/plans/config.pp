plan azure::config (
    TargetSpec $targets,
    Optional[String] $action = 'apply',
    Optional[String] $hostname = undef,
    Optional[String] $instances = undef,
    String $subnet = lookup('subnet'),
    String $vnet = lookup('vnet'),
    String $resource_group = lookup('resource_group'),
    String $peserver = lookup('pe_server')
) {

  #########################################################
  # What to do if we are building an environment in Azure #
  #########################################################

  #########
  # Apply #
  #########

  if ($action == 'apply') {

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

    # Not using puppetserver currently in run
    # $puppetserver = get_target('puppetserver')

    #############################################
    # Pull in Terraform References for Bolt Use #
    #############################################

    # Linux References and mapping to inventory file
    $linuxref = {
        '_plugin'        => 'terraform',
        'dir'            => '~/code/pewazure/azurebolt/terraform',
        'resource_type'  => 'azurerm_linux_virtual_machine',
        'target_mapping' => {
            'uri' => 'public_ip_address',
            'name' => 'name',
            'config' => {
              'ssh'  => {
                'host' => 'public_ip_address',
              }
            }
        }
    }

    # Windows References and mapping to inventory file
    $windowsref = {
        '_plugin'        => 'terraform',
        'dir'            => '~/code/pewazure/azurebolt/terraform',
        'resource_type'  => 'azurerm_windows_virtual_machine',
        'target_mapping' => {
            'uri' => 'public_ip_address',
            'name' => 'name',
            'config' => {
              'winrm'  => {
                'host' => 'public_ip_address',
              }
            }
        }
    }

    # Assigning resolved reference to variables for ease of use
    $linuxsvrs = resolve_references($linuxref)
    $winsrvrs = resolve_references($windowsref)

    ##########################
    # Perform Target Actions #
    ##########################

    # Populate linux targets
    $lin_targets = $linuxsvrs.map |$target| {
        Target.new($target)
    }

    # Populate windows targets
    $win_targets = $winsrvrs.map |$target| {
        Target.new($target)
    }

    # Populate all targets variable
    $alltargs = get_targets([$win_targets, $lin_targets])

    # Download puppet agent from PE Server and install on Windows nodes and autosign
    if ($win_targets) {
      $winpeinst = '[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}; $webClient = New-Object System.Net.WebClient; $webClient.DownloadFile("https://pemozes.iiwtyyvgvfre1fq0t3cfwbyrpf.xx.internal.cloudapp.net:8140/packages/current/install.ps1", "C:\\Users\\adminuser\\Downloads\\install.ps1"); C:\\Users\\adminuser\\Downloads\\install.ps1 custom_attributes:challengePassword=my1securepasswd'

      run_command($winpeinst, $win_targets)
    }

    # Download puppet agent from PE server and install on Linux nodes and autosign
    if ($lin_targets){
      $linpeinstall = 'curl --insecure "https://pemozes.iiwtyyvgvfre1fq0t3cfwbyrpf.xx.internal.cloudapp.net:8140/packages/current/install.bash" | sudo bash -s custom_attributes:challengePassword=my1securepasswd'

      run_command($linpeinstall, $lin_targets)
    }

    run_command('puppet agent -t', $alltargs)
    # run_plan('reboot', $alltargs)
    # wait_until_available($alltargs, 'wait_time' => 300)
  }

  ###########
  # Destroy #
  ###########

  if ($action == 'destroy'){

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
}
