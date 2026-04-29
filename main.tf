terraform {
  required_version = ">= 1.0.0"
  required_providers {
    snowflake = {
      source  = "snowflake-labs/snowflake"
      version = "~> 1.1.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ------------------------------------------------------------------------------
# VARIABLES
# ------------------------------------------------------------------------------

variable "organization_name" {
  type        = string
  description = "Nombre de la organización en Snowflake"
}

variable "account_name" {
  type        = string
  description = "Nombre de la cuenta en Snowflake"
}

variable "user" {
  type        = string
  description = "Usuario de servicio para Terraform (ej. SVC_TERRAFORM)"
}

variable "private_key" {
  type        = string
  sensitive   = true
  description = "Llave privada en formato PEM para autenticación JWT"
}

variable "role" {
  type        = string
  default     = "SYSADMIN"
  description = "Rol principal para creación de infraestructura"
}

# ------------------------------------------------------------------------------
# PROVIDERS
# ------------------------------------------------------------------------------

provider "snowflake" {
  account       = "${var.organization_name}-${var.account_name}"
  user          = var.user
  role          = var.role
  authenticator = "SNOWFLAKE_JWT"
  private_key   = var.private_key
}

provider "snowflake" {
  alias         = "useradmin"
  account       = "${var.organization_name}-${var.account_name}"
  user          = var.user
  role          = "USERADMIN"
  authenticator = "SNOWFLAKE_JWT"
  private_key   = var.private_key
}

# ------------------------------------------------------------------------------
# INFRAESTRUCTURA CORE
# ------------------------------------------------------------------------------

resource "snowflake_database" "tf_db" {
  name    = "TF_DEMO_DB"
  comment = "Base de datos gestionada por Terraform v2.x"
}

resource "snowflake_warehouse" "tf_warehouse" {
  name           = "TF_DEMO_WH"
  warehouse_size = "XSMALL"
  auto_suspend   = 60
  auto_resume    = true
}

resource "snowflake_schema" "tf_db_tf_schema" {
  name     = "TF_DEMO_SC"
  database = snowflake_database.tf_db.name
}

# ------------------------------------------------------------------------------
# IDENTIDAD Y ACCESOS
# ------------------------------------------------------------------------------

resource "snowflake_account_role" "tf_role" {
  provider = snowflake.useradmin
  name     = "TF_DEMO_ROLE"
}

resource "tls_private_key" "svc_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "snowflake_user" "tf_user" {
  provider          = snowflake.useradmin
  name              = "TF_DEMO_USER"
  default_warehouse = snowflake_warehouse.tf_warehouse.name
  default_role      = snowflake_account_role.tf_role.name
  rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

# ------------------------------------------------------------------------------
# PRIVILEGIOS (SINTAXIS MODERNA v1.1.0+)
# ------------------------------------------------------------------------------

resource "snowflake_grant_privileges_to_role" "grant_usage_db" {
  provider   = snowflake.useradmin
  privileges = ["USAGE"]
  role_name  = snowflake_account_role.tf_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.tf_db.name
  }
}

resource "snowflake_grant_role" "grant_role_to_user" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.tf_role.name
  user_name = snowflake_user.tf_user.name
}
