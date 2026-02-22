terraform {
  backend "s3" {
    bucket = "cloudformation-oriebound"
    key    = "metainspect/terraform/dev/terraform.tfstate"
    region = "us-east-1"
  }
}
