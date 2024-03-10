terraform {
  backend "s3" {
    bucket = "tfstate-ramgopalassigment-08"
    key    = "backend/08-prodiosassignment.tfstate"
    region = "us-east-1"
    #dynamodb_table = "remote-backend"
  }
}    