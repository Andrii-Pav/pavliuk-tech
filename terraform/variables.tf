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

variable "alert_email" {
  description = "Пошта для сповіщень CloudWatch (вказати в terraform.tfvars)"
  type        = string
}

variable "cache_enabled" {
  description = "Чи вмикати кеш Redis у застосунку (false — для прогону тесту без кешу)"
  type        = bool
  default     = true
}

variable "cache_ttl_seconds" {
  description = "Скільки секунд живе запис у кеші"
  type        = number
  default     = 30
}

variable "enable_schedule" {
  description = "Бонус 8: масштабування за розкладом (вдень мінімум 2, вночі 1)"
  type        = bool
  default     = false
}
