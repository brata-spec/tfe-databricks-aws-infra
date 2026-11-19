# account-level/env -> TFE workspace dpl-account-prod  (AWS account 283923227867)
# environment and aws_account_id are set by tfe/ on the workspace, not here.

region = "us-east-1"

# New VPC (NAT per AZ, S3 gateway endpoint). Switch to mode = "existing" to reuse one.
network = {
  mode = "create"
  create = {
    vpc_cidr            = "10.20.0.0/16"
    azs                 = ["us-east-1a", "us-east-1b"]
    public_subnet_cidr  = "10.20.240.0/24"
    interface_endpoints = false # true = STS + Kinesis interface endpoints
    endpoint_subnet_cidrs = {
      "us-east-1a" = "10.20.250.0/28"
      "us-east-1b" = "10.20.250.16/28"
    }
  }
}

root_storage = {
  versioning = true
}

teams = {
  ae = {
    new_subnets = {
      "us-east-1a" = "10.20.0.0/20"
      "us-east-1b" = "10.20.16.0/20"
    }
  }
  de = {
    new_subnets = {
      "us-east-1a" = "10.20.32.0/20"
      "us-east-1b" = "10.20.48.0/20"
    }
  }
}

tags = {
  CostCenter = "data-platform"
}
