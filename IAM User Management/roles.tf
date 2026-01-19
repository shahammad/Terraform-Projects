############################
# Local variables
############################
locals {
  # Map of IAM roles to the AWS managed policies
  # that should be attached to each role
  role_policies = {
    readonly = [
      "ReadOnlyAccess"
    ]
    admin = [
      "AdministratorAccess"
    ]
    auditor = [
      "SecurityAudit"
    ]
    developer = [
      "AmazonVPCFullAccess",
      "AmazonEC2FullAccess",
      "AmazonRDSFullAccess"
    ]
  }

  # Flatten the role -> policies map into a list of objects
  # This makes it easier to iterate when attaching policies
  # Example output:
  # [
  #   { role = "admin", policy = "AdministratorAccess" },
  #   { role = "developer", policy = "AmazonEC2FullAccess" },
  #   ...
  # ]
  role_policies_list = flatten([
    for role, policies in local.role_policies : [
      for policy in policies : {
        role   = role
        policy = policy
      }
    ]
  ])
}

############################
# Get AWS account information
############################
# Used to dynamically build ARNs (e.g., user ARNs)
data "aws_caller_identity" "current" {}

############################
# IAM Assume Role Policy
############################
# Creates an assume role policy document per role
# defining which IAM users are allowed to assume it
data "aws_iam_policy_document" "assume_role_policy" {
  # One policy document per role
  for_each = toset(keys(local.role_policies))

  statement {
    # Allow users to assume the role via STS
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"

      # Build a list of IAM user ARNs that are allowed
      # to assume this role
      identifiers = [
        for username in keys(aws_iam_user.users) :
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${username}"
        # Only include users that are mapped to this role
        if contains(local.users_map[username], each.value)
      ]
    }
  }
}

############################
# IAM Roles
############################
# Create one IAM role per entry in role_policies
resource "aws_iam_role" "roles" {
  for_each = toset(keys(local.role_policies))

  # Role name matches the key (e.g., admin, readonly, developer)
  name = each.key

  # Attach the generated assume role policy
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[each.value].json
}

############################
# Fetch AWS Managed Policies
############################
# Look up AWS-managed IAM policies by name
# so they can be attached to roles
data "aws_iam_policy" "managed_policies" {
  # Unique list of policy names
  for_each = toset(local.role_policies_list[*].policy)

  arn = "arn:aws:iam::aws:policy/${each.value}"
}

############################
# Attach Policies to Roles
############################
# Attach each managed policy to its corresponding role
resource "aws_iam_role_policy_attachment" "role_policy_attachments" {
  # One attachment per role-policy combination
  count = length(local.role_policies_list)

  # Target role
  role = aws_iam_role.roles[
    local.role_policies_list[count.index].role
  ].name

  # Managed policy to attach
  policy_arn = data.aws_iam_policy.managed_policies[
    local.role_policies_list[count.index].policy
  ].arn
}