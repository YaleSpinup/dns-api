#!/bin/bash
# Ruby API container runtime script
#
# Gets config properties file from S3 or swarm secrets, decrypts (if from S3) and exports env variables,
# then substitutes env variables into parameterized config files.
#
# This script expects S3URL env variable with the full S3 path to the encrypted config file or a file
# located in /var/run/secrets/config.txt.
#
# Finally this runs unicorn

# list of configuration files that contain parameters to be substituted
# - must specify full path to each file in the container
# - there needs to be a corresponding .template file in the same directory
CONFIG_FILES=(
'/opt/api/config/config.yml'
)

# Do not modify below this line
SECRETSDIR='/var/run/secrets'

if [ -n "$S3URL" ]; then
  echo "Getting config file from S3 (${S3URL}) ..."
  SECRETSDIR='./secrets'
  mkdir -p ${SECRETSDIR}

  aws --version
  if [[ $? -ne 0 ]]; then
    echo "ERROR: aws-cli not found!"
    exit 1
  fi
  aws --region us-east-1 s3 cp ${S3URL} ./config.encrypted
  aws --region us-east-1 kms decrypt --ciphertext-blob fileb://config.encrypted --output text --query Plaintext | base64 --decode > ${SECRETSDIR}/config.txt
fi

if [ ! -f ${SECRETSDIR}/config.txt ]; then
  echo "Secret file not found!"
  exit 1
fi

set -a
source ${SECRETSDIR}/config.txt
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

# Start server
bundle exec puma -C config/puma.rb -p 8080

