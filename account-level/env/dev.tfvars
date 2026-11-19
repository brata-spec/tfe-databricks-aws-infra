# account-level/env -> TFE workspace dpl-account-dev  (AWS account 473640421776)
# environment and aws_account_id are set by tfe/ on the workspace, not here.

region = "us-east-1"

# Reuse the EXISTING dev VPC (10.10.0.0/16, owned outside this repo).
# Only new subnets / security groups are created in it. Already used in that VPC:
#   10.10.0.0/19, 10.10.32.0/19 (dbx-dev), 10.10.64.0/20, 10.10.80.0/20 (dbxp-dev-de), 10.10.248.0/24 (NAT)
network = {
  mode = "existing"
  existing = {
    vpc_id = "vpc-03950e5934415cd3c"
    private_route_table_ids = { # AZ => private route table (with a NAT route)
      "us-east-1a" = "rtb-06d59590ec53661a3"
      "us-east-1b" = "rtb-0156dc945c183d77d"
    }
    endpoint_security_group_ids = ["sg-0d0c3683a000e944e"] # existing STS/Kinesis interface endpoints
  }
}

root_storage = {
  versioning = true
}

# One entry per team: 2 private subnets in 2 AZs, never shared between teams.
# Pick free /20 ranges inside 10.10.0.0/16 (see the list above).
teams = {
  ae = {
    new_subnets = {
      "us-east-1a" = "10.10.96.0/20"
      "us-east-1b" = "10.10.112.0/20"
    }
  }
  de = {
    new_subnets = {
      "us-east-1a" = "10.10.128.0/20"
      "us-east-1b" = "10.10.144.0/20"
    }
  }
}

tags = {
  CostCenter = "data-platform"
}
