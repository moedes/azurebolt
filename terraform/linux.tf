# provider "azurerm" {
#   features {}
# }

resource "azurerm_resource_group" "RG" {
  name     = var.Resource_Group
  location = "West US 2"
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network
  address_space       = ["192.168.25.0/24"]
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "pe_subnet" {
  name                 = var.pe_subnet
  resource_group_name  = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["192.168.25.0/24"]
}

resource "azurerm_network_interface" "nix_int" {
  name                = "nix_int"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pe_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.nix0-pip.id
  }
}

resource "azurerm_public_ip" "nix0-pip" {
    name = "nix0-pip"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    allocation_method = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "nix0" {
  name                = "nix0"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nix_int.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}