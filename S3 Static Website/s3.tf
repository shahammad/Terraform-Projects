############################
# Random suffix for S3 bucket
############################
# Generates a random value to ensure the bucket name is globally unique
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

############################
# S3 Bucket
############################
# Create an S3 bucket to host the static website
resource "aws_s3_bucket" "static_website" {
  # Bucket names must be globally unique
  bucket = "terraform-course-project-1-${random_id.bucket_suffix.hex}"
}

############################
# Public Access Configuration
############################
# Disable S3 public access blocking so the bucket
# can be publicly readable (required for static websites)
resource "aws_s3_bucket_public_access_block" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # Allow public ACLs and policies
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

############################
# Bucket Policy
############################
# Attach a bucket policy that allows public read access
# to all objects in the bucket
resource "aws_s3_bucket_policy" "static_website_public_read" {
  bucket = aws_s3_bucket.static_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        # Allow public access to all objects in the bucket
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}

############################
# Static Website Configuration
############################
# Enable static website hosting on the S3 bucket
resource "aws_s3_bucket_website_configuration" "static_website" {
  bucket = aws_s3_bucket.static_website.id

  # Default page served at the root URL
  index_document {
    suffix = "index.html"
  }

  # Page served when an error occurs (e.g., 404)
  error_document {
    key = "error.html"
  }
}

############################
# Website Content
############################
# Upload the main index page
resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.static_website.id
  key    = "index.html"

  # Local file to upload
  source = "build/index.html"

  # Forces update if the file content changes
  etag = filemd5("build/index.html")

  content_type = "text/html"
}

# Upload the error page
resource "aws_s3_object" "error_html" {
  bucket = aws_s3_bucket.static_website.id
  key    = "error.html"

  source = "build/error.html"
  etag   = filemd5("build/error.html")

  content_type = "text/html"
}
