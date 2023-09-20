variable "aws_region" {
  default     = "eu-west-1"
}

variable "aws_resource_prefix" {}

variable "additional_tags" {
  default = {
    Confidentiality = "Private"
    Environment     = "Dev"
    Project         = "cliff-project"
  }
  type = map(string)
}
