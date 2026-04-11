variable "name" {
  type = string
}

variable "app_service_id" {
  type = string
}

variable "app_settings" {
  type    = map(string)
  default = {}
}

