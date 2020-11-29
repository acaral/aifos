#Author: Alejandro Caral
#Project AIFOS

variable "location" {
  type        = string
  default     = "eastus"
  description = "The location of the resources in Azure"
}

variable "project" {
    type    =   string
    default = "aifos"
    description = "Name of the project"
}
variable "port" {
    type = number
    default = 3333
    description = "Port use to redirect traffic"
}
provider "azurerm" {
  version = "~>2.0"
  features {}
}

resource "azurerm_resource_group" "rg" {
  name = var.project
  location = var.location
   tags = {
      env = "terraform"
  }
}

resource "azurerm_virtual_network" "vn" {
    name = "${var.project}-vnet"
    address_space = ["10.0.0.0/16"]
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    tags = {
      env = "terraform"
  }
}

resource "azurerm_subnet" "subnet" {
    name                 = "${var.project}-subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vn.name
    address_prefixes       = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
    name                = "${var.project}-nsg"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        env = "terraform"
    }
}

resource "azurerm_public_ip" "server-ip" {
    allocation_method = "Dynamic"
    location = var.location
    name = "${var.project}-server-ip"
    resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_interface" "vnic" {
    name                        = "${var.project}-vnic"
    location                    = var.location
    resource_group_name         = azurerm_resource_group.rg.name
    ip_configuration {
        public_ip_address_id = azurerm_public_ip.server-ip.id
        name = "vnic-ip"
        private_ip_address_allocation = "Dynamic"
        subnet_id                     = azurerm_subnet.subnet.id
    }

    tags = {
        env = "terraform"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsg-association" {
    network_interface_id      = azurerm_network_interface.vnic.id
    network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

output "tls_private_key" { value = tls_private_key.ssh.private_key_pem }

resource "azurerm_linux_virtual_machine" "server" {
    name                  = "${var.project}server"
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg.name
    network_interface_ids = [azurerm_network_interface.vnic.id]
    size                  = "Standard_B1ls"

    os_disk {
        name              = "${var.project}-disk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "${var.project}-server"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.ssh.public_key_openssh
    }

    tags = {
        env = "terraform"
    }
}

resource "azurerm_dns_zone" "dnszone" {
  #location = "eastus"
  name = "smartapphouses.com"
  resource_group_name = azurerm_resource_group.rg.name
}

output "azurerm_dns_zone" { value = azurerm_dns_zone.dnszone.name_servers }

resource "local_file" "name_server" {
    content = join(", ", azurerm_dns_zone.dnszone.name_servers)
    filename = "dns_name_servers.txt"
}

resource "local_file" "server-ip" {
    content = data.azurerm_public_ip.server-ip.ip_address
    filename = "server-ip.txt"
}

resource "local_file" "sesrver_key" {
  content  = tls_private_key.ssh.private_key_pem
  filename = "server_key.pem"
}

output "server-ip" {
    value = data.azurerm_public_ip.server-ip.ip_address
}

data "azurerm_public_ip" "server-ip" {
  depends_on = [azurerm_linux_virtual_machine.server]
  name                = azurerm_public_ip.server-ip.name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_dns_a_record" "server-dns-ip" {
    name = var.project
    resource_group_name = azurerm_resource_group.rg.name
    ttl = 3600
    zone_name = azurerm_dns_zone.dnszone.name
    records = [data.azurerm_public_ip.server-ip.ip_address]
}

/*resource "azurerm_virtual_machine_extension" "cloudinit" {
    name = "boot_script"
    publisher = "Microsoft.Azure.Extensions"
    type = "CustomScript"
    type_handler_version = "2.0"
    virtual_machine_id = azurerm_linux_virtual_machine.server.id
    settings = <<SETTINGS
    {
        "commandToExecute": "curl -sSL https://raw.githubusercontent.com/acaral/aifos/main/start_script.sh | sudo bash"
    }
    SETTINGS
}*/

resource "azurerm_virtual_machine_extension" "cloudinit" {
    name = "boot_script"
    virtual_machine_id = azurerm_linux_virtual_machine.server.id
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.0"
    settings = <<SETTINGS
    {
        "script": "${base64encode(templatefile("boot_script.sh", {project=var.project}))}"
    }
    SETTINGS
}
