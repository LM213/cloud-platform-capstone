terraform {
  backend "s3" {
    bucket         = "c-p-c"
    key            = "global/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "db-cpc"
    encrypt        = true
  }
}
