#!/bin/sh

# Prevent AWS CLI from opening Vim or less pager for long output
export AWS_PAGER=""

# Variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ca-central-1" # Change this to your AWS region
REPOSITORY_NAME="organization-images"
IMAGE_NAME="hapi_fhir_jspaserver_cambian"
IMAGE_TAG="v1"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Build the Docker image in linux/ARM64 architecture, same has been configured in the template.
docker build --platform linux/arm64 -t ${REPOSITORY_NAME}:${IMAGE_NAME}-${IMAGE_TAG} .

# Authenticate Docker with ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}

# Check if the repository exists
if aws ecr describe-repositories --repository-names "${REPOSITORY_NAME}" --region ${AWS_REGION} > /dev/null 2>&1; then
  echo "Repository ${REPOSITORY_NAME} already exists."
else
  echo "Repository ${REPOSITORY_NAME} does not exist. Creating it now..."
  aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region ${AWS_REGION}
fi

# Tag the Docker image
docker tag ${REPOSITORY_NAME}:${IMAGE_NAME}-${IMAGE_TAG} ${ECR_URI}/${REPOSITORY_NAME}:${IMAGE_NAME}-${IMAGE_TAG}

# Push the Docker image to ECR
docker push ${ECR_URI}/${REPOSITORY_NAME}:${IMAGE_NAME}-${IMAGE_TAG}

echo "Image ${REPOSITORY_NAME}:${IMAGE_NAME}-${IMAGE_TAG} pushed to ECR successfully."
