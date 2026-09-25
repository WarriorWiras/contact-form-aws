variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "contact-demo"
}

variable "name" {
  type    = string
  default = "contact-demo"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,26}$", var.name))
    error_message = "Use 3-27 lowercase letters, digits and dashes, starting with a letter."
  }
}

variable "operator_cidr" {
  type        = string
  description = "Your workstation's current public IPv4 address as /32; EKS API is restricted to this range."
  validation {
    condition     = can(cidrhost(var.operator_cidr, 0)) && endswith(var.operator_cidr, "/32")
    error_message = "Supply one IPv4 address with /32, for example 203.0.113.25/32."
  }
}

variable "eks_version" {
  type    = string
  default = "1.35"
}

variable "node_count" {
  type        = number
  description = "Desired private worker nodes; use 0 while paused and 2 for the live demo."
  default     = 2
  validation {
    condition     = contains([0, 1, 2], var.node_count)
    error_message = "node_count must be 0, 1 or 2."
  }
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
