terraform {
  required_providers {
    snowflake = {
      source  = "snowflake-labs/snowflake"
      version = "~> 0.94.0" # Versión estable y actual
    }
  }
}

# Declaración de variables (HCP Terraform las llenará automáticamente)
variable "organization_name" {}
variable "account_name" {}
variable "user" {}
variable "private_key" {}
variable "role" {}

# Provider principal (Usando SYSADMIN para crear DB y Warehouse)
provider "snowflake" {
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  role              = var.role
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.private_key
}

# Provider secundario con Alias para USERADMIN
provider "snowflake" {
  alias             = "useradmin"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  role              = "USERADMIN"
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = var.private_key
}

# --- RECURSOS ---

# 1. Crear la Base de Datos
resource "snowflake_database" "tf_db" {
  name         = "TF_DEMO_DB"
  is_transient = false
}

# 2. Crear el Warehouse
resource "snowflake_warehouse" "tf_warehouse" {
  name                = "TF_DEMO_WH"
  warehouse_type      = "STANDARD"
  warehouse_size      = "XSMALL"
  auto_suspend        = 60
  auto_resume         = true
  initially_suspended = true
}

# 3. Crear el Esquema
resource "snowflake_schema" "tf_db_tf_schema" {
  name     = "TF_DEMO_SC"
  database = snowflake_database.tf_db.name
}

# 4. Crear un nuevo Rol (Usa el alias useradmin)
resource "snowflake_account_role" "tf_role" {
  provider = snowflake.useradmin
  name     = "TF_DEMO_ROLE"
  comment  = "Rol creado por Terraform"
}

# 5. Generar llave para el nuevo usuario
resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 6. Crear un nuevo Usuario (Usa el alias useradmin)
resource "snowflake_user" "tf_user" {
  provider          = snowflake.useradmin
  name              = "TF_DEMO_USER"
  default_warehouse = snowflake_warehouse.tf_warehouse.name
  default_role      = snowflake_account_role.tf_role.name
  rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

# 7. Privilegios de Uso sobre la DB
resource "snowflake_grant_privileges_to_account_role" "grant_usage_db" {
  provider          = snowflake.useradmin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.tf_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.tf_db.name
  }
}
