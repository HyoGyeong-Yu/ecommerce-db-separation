variable "region"       { default = "ap-northeast-2" }
variable "project_name" { default = "ecommerce-portfolio" }
variable "vpc_cidr"     { default = "10.0.0.0/16" }

variable "azs"                  { default = ["ap-northeast-2a", "ap-northeast-2c"] }
variable "public_subnet_cidrs"  { default = ["10.0.1.0/24", "10.0.2.0/24"] }
variable "private_subnet_cidrs" { default = ["10.0.11.0/24", "10.0.12.0/24"] }
