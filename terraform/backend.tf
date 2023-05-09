terraform {
  backend "s3" {
    key    = "test/terraform.state"
    region = "us-east-1"
  }
}
