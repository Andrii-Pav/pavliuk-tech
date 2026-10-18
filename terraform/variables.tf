variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "pavliuk-tech"
}

variable "db_name" {
  type    = string
  default = "pavliuk_tech"
}

variable "db_username" {
  type    = string
  default = "pavliuk"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "cpu_architecture" {
  type    = string
  default = "X86_64"
}

variable "container_port" {
  type    = number
  default = 8000
}
