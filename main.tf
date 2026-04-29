terraform {
  required_providers {
    snowflake = {
      source  = "snowflake-labs/snowflake"
      version = "~> 1.1.0" # Forzamos la versión más moderna
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# --- VARIABLES ---
variable "organization_name" { type = string }
variable "account_name"      { type = string }
variable "user"              { type = string }
variable "private_key"       { type = string; sensitive = true }
variable "role"              { type = string; default = "SYSADMIN" }

# --- PROVIDERS (Sintaxis v2.x) ---

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

# --- RECURSOS DE INFRAESTRUCTURA ---

resource "snowflake_database" "tf_db" {
  name    = "TF_DEMO_DB"
  comment = "Gestionada con Snowflake Provider v2.x"
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

# --- IDENTIDAD Y SEGURIDAD ---

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
  # Nota: En v1.1+ asegúrate de que el formato de llave sea compatible
  rsa_public_key    = substr(tls_private_key.svc_key.public_key_pem, 27, 398)
}

# --- NUEVA SINTAXIS DE PRIVILEGIOS (v1.x / v2.x) ---

# Reemplaza a snowflake_grant_privileges_to_account_role
resource "snowflake_grant_privileges_to_role" "grant_usage_db" {
  provider   = snowflake.useradmin
  privileges = ["USAGE"]
  role_name  = snowflake_account_role.tf_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.tf_db.name
  }
}

# Asignar rol a usuario (Sintaxis moderna)
resource "snowflake_grant_role" "grant_role_to_user" {
  provider  = snowflake.useradmin
  role_name = snowflake_account_role.tf_role.name
  user_name = snowflake_user.tf_user.name
}
