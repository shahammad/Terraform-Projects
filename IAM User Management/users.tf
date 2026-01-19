############################
# Local variables
############################
locals {
  # Load user-role mappings from an external YAML file
  # Expected YAML structure:
  # users:
  #   - username: alice
  #     roles: [admin, developer]
  #   - username: bob
  #     roles: [readonly]
  users_from_yaml = yamldecode(
    file("${path.module}/user-roles.yaml")
  ).users

  # Convert the list of user objects into a map:
  # {
  #   "alice" = ["admin", "developer"]
  #   "bob"   = ["readonly"]
  # }
  # This structure allows fast lookups when assigning role access
  users_map = {
    for user_config in local.users_from_yaml :
    user_config.username => user_config.roles
  }
}

############################
# IAM Users
############################
# Create one IAM user per username defined in the YAML file
resource "aws_iam_user" "users" {
  # Use a set to ensure usernames are unique
  for_each = toset(local.users_from_yaml[*].username)

  # IAM username
  name = each.value
}

############################
# IAM User Login Profiles
############################
# Create console login credentials for each IAM user
resource "aws_iam_user_login_profile" "users" {
  # One login profile per IAM user
  for_each = aws_iam_user.users

  # Associate the login profile with the IAM user
  user = each.value.name

  # Initial password length (AWS will generate the password)
  password_length = 8

  lifecycle {
    # Prevent Terraform from forcing password recreation
    # on every plan/apply due to computed or rotated values
    ignore_changes = [
      password_length,
      password_reset_required,
      pgp_key
    ]
  }
}

############################
# Outputs
############################
# Output generated passwords for initial distribution
# Marked as sensitive so they are hidden in CLI output
output "passwords" {
  sensitive = true

  # Map of username => generated password
  value = {
    for user, user_login in aws_iam_user_login_profile.users :
    user => user_login.password
  }
}
