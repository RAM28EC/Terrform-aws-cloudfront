variable "project_name"{}
variable "ami" {
    default = "ami-053b0d53c279acc90"
}
variable "cpu" {
    default = "t2.micro"
}
variable "key_name" {}
variable "client_sg_id" {}
variable "max_size" {
    default = 2
}
variable "min_size" {
    default = 1
}
variable "desired_cap" {
    default = 1
}
variable "asg_health_check_type" {
    default = "ELB"
}
variable "pri_sub_3a_id" {}
variable "pri_sub_4b_id" {}
variable "tg_arn" {}
variable "s3_bucket_name" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {}
variable "aws_region" {}