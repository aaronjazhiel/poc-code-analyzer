#!/bin/bash

# PoC Code Analyzer - Deployment Script
# ======================================

echo "🚀 Deploying PoC Code Analyzer Lambda Functions"
echo ""

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo "❌ AWS SAM CLI not found. Install it first:"
    echo "   brew install aws-sam-cli"
    exit 1
fi

# Prompt for Bedrock Agent IDs
read -p "Enter Supervisor Agent ID: " SUPERVISOR_AGENT_ID
read -p "Enter Supervisor Agent Alias ID: " SUPERVISOR_AGENT_ALIAS_ID

echo ""
echo "📦 Building SAM application..."
sam build

echo ""
echo "🚀 Deploying to AWS..."
sam deploy \
  --parameter-overrides \
    SupervisorAgentId=$SUPERVISOR_AGENT_ID \
    SupervisorAgentAliasId=$SUPERVISOR_AGENT_ALIAS_ID \
    S3BucketName=poc-code-analyzer-2026

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Configure AS-IS Agent Action Group to use: bedrock-asis-lambda"
echo "   2. Configure TO-BE Agent Action Group to use: bedrock-tobe-lambda"
echo "   3. Test with: aws lambda invoke --function-name invoke-supervisor-agent ..."
