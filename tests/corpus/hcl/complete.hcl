# Complete HCL lexical corpus
terraform {
  required_version = ">= 1.6"
}

variable "image" {
  type    = string
  default = null
}

locals {
  enabled = true
  count   = 3
  tags    = merge({ env = "dev\n<&>" }, var.extra_tags)
}

resource "example_service" "web" {
  image = var.image
  name  = "service-${var.image}"
  text  = <<-EOF
    instance ${var.image} <&>
  EOF

  /* bounded block comment */
  ports = [80, 443]
}
