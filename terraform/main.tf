provider "aws" {
  region = var.aws_region
}

###################################################################
### AWS lambda creation with required role and policies
###################################################################

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "awslambda_role" {
  name               = "${var.aws_resource_prefix}_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_cloudwatch_log_group" "eks-logs" {
  name              = "/aws/lambda/${aws_lambda_function.aws_lambda.function_name}"
  retention_in_days = 14
  tags              = var.additional_tags
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }

}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.aws_resource_prefix}_lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.awslambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "aws_kinesis_access_lambda" {
  role       = aws_iam_role.awslambda_role.name
  policy_arn = data.aws_iam_policy.aws_kinesis_access.arn
}

data "aws_iam_policy" "aws_kinesis_access" {
  arn = "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
}

##########################################################################
### Python code to be run within lambda ###
##########################################################################
data "archive_file" "aws_lambda" {
  type        = "zip"
  source_file = "${path.module}/scripts/lambda-function/GeneratePageviewEventsLambda.py" 
  output_path = "${path.module}/scripts/lambda-function/GeneratePageviewEventsLambda.zip"
}

###########################################################################
### Lambda function creation ###
###########################################################################

resource "aws_lambda_function" "aws_lambda" {
  filename         = data.archive_file.aws_lambda.output_path
  source_code_hash = data.archive_file.aws_lambda.output_base64sha256
  role             = aws_iam_role.awslambda_role.arn

  function_name = "${var.aws_resource_prefix}-awslambda"
  handler       = "awslambda.lambda_handler"
  runtime       = "python3.11"
  timeout       = 180
  tags = var.additional_tags
}

###########################################################################
### Kinesis datastream creation ###
###########################################################################

resource "aws_kinesis_stream" "kinesis_stream" {
  name             = "${var.aws_resource_prefix}-aws-kinesis-stream"
  shard_count      = 1
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = var.additional_tags
}
