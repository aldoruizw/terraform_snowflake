terraform {
  required_providers {
    snowflake = {
      source = "snowflakedb/snowflake"
    }
  }

  cloud {
    organization = "aldoruizw"
    workspaces {
      name = "gh-actions-demo"
    }
  }
}

variable "private_key" {
  type      = string
  sensitive = true
}

variable "organization_name" {
  type = string
}

variable "account_name" {
  type = string
}

variable "user" {
  type = string
}

variable "role" {
  type = string
}

variable "authenticator" {
  type = string
}

provider "snowflake" {
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.user
  role              = var.role
  authenticator     = var.authenticator
  private_key       = var.private_key
}

resource "snowflake_database" "tf_db" {
  name         = "TF_DEMO_DB"
  is_transient = false
}

resource "snowflake_warehouse" "tf_warehouse" {
  name                      = "TF_DEMO_WH"
  warehouse_type            = "STANDARD"
  warehouse_size            = "XSMALL"
  max_cluster_count         = 1
  min_cluster_count         = 1
  auto_suspend              = 60
  auto_resume               = true
  enable_query_acceleration = false
  initially_suspended       = true
}
