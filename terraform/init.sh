#!/bin/bash

echo "Enter values to save terraform variables to env"
echo "Leave blank to enter values at terraform plan/apply"
echo ""

echo "project id:"
read -r project

echo "GCS bucket:"
read -r bucket

echo "email to send from:"
read -r from_email

echo "comma-separated list of emails to send to:"
read -r to_email

echo "database password (hidden):"
read -sr db_pass

echo "slack api key (hidden):"
read -sr slack_key

echo "sendgrid api key (hidden):"
read -sr sendgrid_key

echo "" > terraform.tfvars

if [[ -n $project ]]; then
  echo "project = \"$project\"" >> terraform.tfvars
fi

if [[ -n $bucket ]]; then
  echo "bucket_name = \"$bucket\"" >> terraform.tfvars
fi

if [[ -n $from_email ]]; then
  echo "from_email = \"$from_email\"" >> terraform.tfvars
fi

if [[ -n $to_email ]]; then
  echo "to_email = \"$to_email\"" >> terraform.tfvars
fi

if [[ -n $db_pass ]]; then
  echo "db_pass = \"$db_pass\"" >> terraform.tfvars
fi

if [[ -n $slack_key ]]; then
  echo "slack_key = \"$slack_key\"" >> terraform.tfvars
fi

if [[ -n $sendgrid_key ]]; then
  echo "sendgrid_key = \"$sendgrid_key\"" >> terraform.tfvars
fi