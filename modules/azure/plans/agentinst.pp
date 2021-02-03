plan azure::agentinst (
  String $challenge = lookup('challenge'),
  String $peserver = lookup('peserver'),
  String $domainname = lookup('domain')
) {
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
            'name' => 'name',
            'uri'  => 'public_ip_address'
          }
    }

    # Assigning resolved reference to variables for ease of use
    $linuxsvrs = resolve_references($linuxref)
    $winsrvrs = resolve_references($windowsref)

    ##########################
    # Perform Target Actions #
    ##########################

    # Populate linux references to inventory cached linux group
    $lin_targets = $linuxsvrs.map |$target| {
        Target.new($target).add_to_group('linux')
    }

    # Populate windows references to inventory cached windows group
    $win_targets = $winsrvrs.map |$target| {
        Target.new($target).add_to_group('windows')
    }

    # Populate all targets variable
    $alltargs = get_targets([$win_targets, $lin_targets])

    # Download puppet agent from PE Server and install on Windows nodes and autosign
    if ($win_targets) {

      $winpeinst = "[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback = \n
                    {\$true}; \$webClient = New-Object System.Net.WebClient; \$webClient.DownloadFile(\"https://${peserver}.${domainname}:8140/packages/current/install.ps1\", \n
                    \"C:\\Users\\adminuser\\Downloads\\install.ps1\"); C:\\Users\\adminuser\\Downloads\\install.ps1 custom_attributes:challengePassword=${challenge}"

      run_command($winpeinst, $win_targets)
    }

    # Download puppet agent from PE server and install on Linux nodes and autosign
    if ($lin_targets){

      $linpeinstall = "curl --insecure \"https://${peserver}.${domainname}:8140/packages/current/install.bash\" | sudo bash -s custom_attributes:challengePassword=${challenge}"

      run_command($linpeinstall, $lin_targets)
    }

    catch_errors() || {
      $result = run_command('puppet agent -t', $alltargs, '_catch_errors' => true)
      out::message($result)
      # run_plan('reboot', $alltargs)
      # wait_until_available($alltargs, 'wait_time' => 300)
    }
}
