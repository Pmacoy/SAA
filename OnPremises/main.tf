# main.tf

provider "azurerm" {
  features {}
}

# Criação do grupo de recursos
resource "azurerm_resource_group" "local" {
  name     = "rg-local"
  location = "East US"
  tags = {
    ambiente = "saa"
  }
}

# Criação da rede virtual
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-local"
  address_space       = ["10.0.0.0/16"]
  location            = "East US"  # Escolha a região desejada
  resource_group_name = azurerm_resource_group.local.name
  tags = {
    ambiente = "saa"
  }
}

# Criação da sub-rede para a aplicação
resource "azurerm_subnet" "subnet-app" {
  name                 = "SUB-APP"
  resource_group_name = azurerm_resource_group.local.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Associação da sub-rede da aplicação ao grupo de segurança de rede
resource "azurerm_subnet_network_security_group_association" "subnet-app-nsg-association" {
  subnet_id               = azurerm_subnet.subnet-app.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Criação da sub-rede para o banco de dados
resource "azurerm_subnet" "subnet-db" {
  name                 = "SUB-DB"
  resource_group_name = azurerm_resource_group.local.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Associação da sub-rede do banco de dados ao grupo de segurança de rede
resource "azurerm_subnet_network_security_group_association" "subnet-db-nsg-association" {
  subnet_id               = azurerm_subnet.subnet-db.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Criação do IP público para a aplicação
resource "azurerm_public_ip" "publicip-app" {
  name                = "meuPublicIP-APP"
  location            = azurerm_resource_group.local.location
  resource_group_name = azurerm_resource_group.local.name
  allocation_method   = "Dynamic"
}

# Criação do IP público para o banco de dados
resource "azurerm_public_ip" "publicip-db" {
  name                = "meuPublicIP-DB"
  location            = azurerm_resource_group.local.location
  resource_group_name = azurerm_resource_group.local.name
  allocation_method   = "Dynamic"
}

# Criação do grupo de segurança de rede
resource "azurerm_network_security_group" "nsg" {
  name                = "NSG-local"
  location            = azurerm_virtual_network.vnet.location
  resource_group_name = azurerm_resource_group.local.name
  tags = {
    ambiente = "saa"
  }
}

# Criação da regra de segurança para permitir RDP
resource "azurerm_network_security_rule" "rdp-rule" {
  name                        = "AllowRDP"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = ["0.0.0.0/0"]  # Permitir acesso de qualquer lugar (não recomendado para produção)
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.local.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Criação da nic da vm app
resource "azurerm_network_interface" "nic-app" {
  name                = "NIC-APP"
  location            = azurerm_virtual_network.vnet.location
  resource_group_name = azurerm_resource_group.local.name
    tags = {
    ambiente = "saa"
  }

  ip_configuration {
    name                          = "ipconfig-app"
    subnet_id                     = azurerm_subnet.subnet-app.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip-app.id
  }
}

# Criação da nic da vm db
resource "azurerm_network_interface" "nic-db" {
  name                = "NIC-DB"
  location            = azurerm_virtual_network.vnet.location
  resource_group_name = azurerm_resource_group.local.name
    tags = {
    ambiente = "saa"
  }

  ip_configuration {
    name                          = "ipconfig-db"
    subnet_id                     = azurerm_subnet.subnet-db.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip-db.id
  }
}

# Criação da vm app
resource "azurerm_virtual_machine" "vm-app" {
  name                  = "VM-APP"
  location              = azurerm_virtual_network.vnet.location
  resource_group_name   = azurerm_resource_group.local.name
  network_interface_ids = [azurerm_network_interface.nic-app.id]
  vm_size               = "Standard_B2s"  # Escolha o tamanho da VM desejado
  delete_os_disk_on_termination = true
    tags = {
    ambiente = "saa"
  }

  # Criação do disco
  storage_os_disk {
    name              = "osdisk-app"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  # Informando a imagem
  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # Informando o user e a password
  os_profile {
    computer_name  = "vm-app"
    admin_username = "admin.pjulio"
    admin_password = "P@ssw0rd123!"  # Defina sua senha de administrador
  }

    # Ativanod o agente
    os_profile_windows_config {
    provision_vm_agent = true
  }
}

# Criação da vm db
resource "azurerm_virtual_machine" "vm-db" {
  name                  = "VM-DB"
  location              = azurerm_virtual_network.vnet.location
  resource_group_name   = azurerm_resource_group.local.name
  network_interface_ids = [azurerm_network_interface.nic-db.id]
  vm_size               = "Standard_B2s"  # Escolha o tamanho da VM desejado
  delete_os_disk_on_termination = true
    tags = {
    ambiente = "saa"
  }

  # Criação do disco
  storage_os_disk {
  name              = "osdisk-db"
  caching           = "ReadWrite"
  create_option     = "FromImage"
  managed_disk_type = "Standard_LRS"
  }

  # Referência de imagem do SQL Server 2022 Free Edition
  storage_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "SQL2019-WS2019"
    sku       = "SQLDEV"
    version   = "latest"
  }

  # Informando o user e a password da vm
  os_profile {
    computer_name  = "vm-db"
    admin_username = "adminsql"
    admin_password = "Partiunuvem@2024"  # Defina sua senha de administrador
  }
  
  # Ativando o agente
  os_profile_windows_config {
    provision_vm_agent = true
  }
}

# # Criando um servidor SQL no Azure
# resource "azurerm_mssql_server" "mssql-server-vm-db" {
#   name                         = "sql-server-vm-db"  # Nome do servidor SQL
#   resource_group_name          = azurerm_resource_group.local.name
#   location                     = azurerm_resource_group.local.location
#   version                      = "12.0"  # SQL Server 2022 Free Edition
#   administrator_login          = "adminsql"  # Nome de usuário para acessar o servidor SQL
#   administrator_login_password = "Partiunuvem@2024"  # Senha de acesso ao servidor SQL
# }

# # Criando um banco de dados no servidor SQL
# resource "azurerm_mssql_database" "database-vm-db" {
#   name                = "database-vm-db"  # Nome do banco de dados
#   server_id           = azurerm_mssql_server.mssql-server-vm-db.id
#   collation           = "SQL_Latin1_General_CP1_CI_AS"
# }

# # Saída do endpoint do servidor SQL
# output "sql_server_endpoint" {
#   value = azurerm_mssql_server.mssql-server-vm-db.fully_qualified_domain_name
# }

# # # Saída do endpoint do banco de dados SQL
# # output "sql_database_endpoint" {
# #   value = azurerm_mssql_database.database-vm-db.fully_qualified_domain_name
# # }