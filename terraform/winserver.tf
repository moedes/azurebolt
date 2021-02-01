resource "azurerm_network_interface" "win_int" {
  name                = "win_int"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pe_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.win0-pip.id
  }
}

resource "azurerm_public_ip" "win0-pip" {
    name = "win0-pip"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    allocation_method = "Dynamic"
}

resource "azurerm_windows_virtual_machine" "win0" {
  name                = "win0"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "Puppetlabs!"
  network_interface_ids = [
    azurerm_network_interface.win_int.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  winrm_listener {
      protocol = "Http"
  } 
}

resource "azurerm_virtual_machine_extension" "win0" {
  name                 = "win0"
  virtual_machine_id = azurerm_windows_virtual_machine.win0.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.8"

  settings = <<SETTINGS
    {
        "commandToExecute": "powershell.exe Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False"
    }
SETTINGS
}