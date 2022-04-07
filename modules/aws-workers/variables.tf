variable "image_id" {}
variable "instance_type" {}
variable "key_name" {}
variable "userdata_script" {
  type        = string
  description = "Userdata script for EC2 instance"
}
variable "worker_subnets" {
  type        = list(string)
  description = "Private subnets where workers will be deployed"
}
variable "vpc_id" {
  type        = string
  description = "VPC ID where workers will be deployed"
}
variable "vpc_security_group_ids" {}