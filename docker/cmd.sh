#!/bin/bash
# Container runtime configuration script
# Gets config file from SSM, and exports env variables, then
#   substitutes env variables into parameterized config files
# This script expects SSMPATH env variable with the path for SSM
#   e.g., /spinup/tst/dnsapi/config

# list of configuration files that contain parameters to be substituted
# - must specify full path to each file in the container
# - there needs to be a corresponding .template file in the same directory
CONFIG_FILES=(
'/opt/api/config/config.yml'
)

# Do not modify below this line

if [ -n "$SSMPATH" ]; then
  echo "Getting config file from SSM (${SSMPATH}) ..."
  aws --version
  if [[ $? -ne 0 ]]; then
    echo "ERROR: aws-cli not found!"
    exit 1
  fi
  aws ssm --region us-east-1 get-parameter --name ${SSMPATH} --with-decryption | jq -r .Parameter.Value | base64 -d > config.txt
  set -a
  source config.txt
  rm -f config.txt config.encrypted

  echo 'Substituting environment variables in config files ...'
  for CONF in "${CONFIG_FILES[@]}"; do
    echo "- ${CONF}"
    if [[ -r "${CONF}.template" ]]; then
      envsubst < "${CONF}.template" > "${CONF}"
      chmod 640 ${CONF}
    else
      echo "ERROR: ${CONF}.template not found!"
      exit 1
    fi
  done

else
  echo "ERROR: SSMPATH variable not set!"
  exit 1
fi

# Start server
bundle exec puma -C config/puma.rb -p 8080

