# dns-api

A RESTful API to manage DNS entries using the [Bluecat Proteus API Client](https://github.com/YaleUniversity/proteus_client).

## API

```
# Basic API information
GET     '/ping'
GET     '/version'
GET     '/'

# Custom search based on type and filters
GET     '/:account/search?type=XXX&filters=XXX'

# Manage entities by ID
GET     '/:account/id/:id
DELETE  '/:account/id/:id

# Manage Zones
GET     '/:account/zones'
GET     '/:account/zones/:id'

# Manage DNS records
GET     '/:account/records?type=(HostRecord|AliasRecord|ExternalHostRecord)'
POST    '/:account/records'
GET     '/:account/records/:id'
PUT     '/:account/records/:id'
DELETE  '/:account/records/:id'

# Manage Networks
GET     '/:account/networks'
GET     '/:account/networks/:id'

# Manage IP addresses
POST    '/:account/ips'
GET     '/:account/ips/:ip
PUT     '/:account/ips/:ip
DELETE  '/:account/ips/:ip'
GET     '/:account/ips/cidrs'

# Manage MAC addresses
POST    '/:account/macs'
GET     '/:account/macs/:mac'
PUT     '/:account/macs'
```

## Authentication

The API uses the "Auth-Token" HTTP header to authenticate all requests (GET, POST, DELETE) using a simple token. You'll
need to submit a valid token in this header with each request (see Examples below).  To generate a token for use by the
API, you can use `uuidgen`, then get a SHA512 digest and store that in the config.yml file, e.g.:

```shell
export PROTEUS_API_AUTH_TOKEN=$(uuidgen)
export AUTH_TOKEN_512=$(ruby -e "require 'digest';puts(Digest::SHA512.hexdigest(\"${PROTEUS_API_AUTH_TOKEN}\"))")
```

## Local Development

Requirements:

 - `rbenv`
 - `bundler`

Setup:

```shell
# Clone repository and install Ruby version specified
 git clone git@git.yale.edu:spinup/dns-api.git ./dns-api
 cd dns-api
 rbenv install $(cat .ruby-version)
```

```shell
# Clean environment of all PROTEUS_ environment variables
while IFS= read -r result; do unset ${result%%=*}; done < <(env | grep PROTEUS_)

# Create configuration file from erb template
export PROTEUS_API_AUTH_TOKEN=$(uuidgen)
export PROTEUS_API_AUTH_TOKEN_512=$(ruby -e "require 'digest';puts(Digest::SHA512.hexdigest(\"${PROTEUS_API_AUTH_TOKEN}\"))")

echo "For testing copy and execute the following in a separate shell:"
echo "export PROTEUS_API_AUTH_TOKEN=${PROTEUS_API_AUTH_TOKEN}"
echo "Supply the following Auth-Token value in the http header: ${PROTEUS_API_AUTH_TOKEN}"

export PROTEUS_URL=<replace_with_bluecat_management url>
export PROTEUS_USER=<replace_with_bluecat_api_username>
export PROTEUS_PASS=<replace_with_bluecat_api_username_password>
export PROTEUS_VIEWID=<replace_with_bluecat_api_username_viewid_from_portal>

# app.rb will load these values from the environment into config.yml.erb
```

```shell
# Run application
bundle install
bundle exec shotgun
```

The app will run and be ready to receive requests at `localhost:9393`. Modifications to the code, will trigger a reload by `shotgun`.

To begin testing, launch a separate shell session.

```shell
# Paste the export command echoed during setup of the application development environment
#   export PROTEUS_API_AUTH_TOKEN=${PROTEUS_API_AUTH_TOKEN}

# verify unprotected routes
curl http://localhost:9393/v1/dns/ping
# You should get a `pong` back.
curl http://localhost:9393/v1/dns/version
# You should `{"version":"<api-version-number>"}

# verify authorization
curl http://localhost:9393/
# You should get "Invalid token".
curl -H "Auth-Token:${PROTEUS_API_AUTH_TOKEN}" http://localhost:9393/
# You should get "Requested resource not found!"
```
No errors logged by the api running in developement shell session logstream in `stdout`.

To test your code:

```shell
# Code lint
bundle exec rubocop
# Execute unit tests
bundle exec rake
```

## Docker

### Local Development and Execution

You can use `Dockerfile.local` to run the app locally in a container:

```shell
# Setup environment as before
while IFS= read -r result; do unset ${result%%=*}; done < <(env | grep PROTEUS_)
export PROTEUS_API_AUTH_TOKEN=$(uuidgen)
export PROTEUS_API_AUTH_TOKEN_512=$(ruby -e "require 'digest';puts(Digest::SHA512.hexdigest(\"${PROTEUS_API_AUTH_TOKEN}\"))")
export PROTEUS_URL=<replace_with_bluecat_management url>
export PROTEUS_USER=<replace_with_bluecat_api_username>
export PROTEUS_PASS=<replace_with_bluecat_api_username_password>
export PROTEUS_VIEWID=<replace_with_bluecat_api_username_viewid_from_portal>

docker build -f docker/Dockerfile.local . -t "localhost/dns-api"

# Pass these values into running container environment
docker run -e PROTEUS_API_AUTH_TOKEN_512=${PROTEUS_API_AUTH_TOKEN_512} \
           -e PROTEUS_URL=${PROTEUS_URL} \
           -e PROTEUS_USER=${PROTEUS_USER} \
           -e PROTEUS_PASS=${PROTEUS_PASS} \
           -e PROTEUS_VIEWID=${PROTEUS_VIEWID} \
           -p 8080:8080 "localhost/dns-api"

# Optionally tag with commit hash
# docker tag "localhost/dns-api" "localhost/dns-api:$(git log -1 --pretty=%h)"
```

Open a second shell. The previous `curl` commands for testing may be used with `8080` substituting for `9393`.

```shell
# verify unprotected routes
curl http://localhost:8080/v1/dns/ping
# You should get a `pong` back.
curl http://localhost:8080/v1/dns/version
# You should `{"version":"<api-version-number>"}

# verify authorization
curl http://localhost:8080/
# You should get "Invalid token".
curl -H "Auth-Token:${PROTEUS_API_AUTH_TOKEN}" http://localhost:8080/
# You should get "Requested resource not found!"

# Stopping the docker container
docker kill $(docker ps -f 'ancestor=localhost/dns-api' -q)
```

### Deployment to Infrastructure

A docker image for deployment to enterprise infrastructure may be created by using the provided`Dockerfile`. A continuous integration tool such as [Jenkins](https://jenkins.io/) manages the necssary configuration values to build the container. (These values are pushed to an encrypted [Amazon S3](https://aws.amazon.com/s3/) container blob decrypted at build time.)

## Examples with cURL

### Create a New Host Record

```bash
# Construct payload
# Specify user-defined fields for Proteus Bluecat
export PROTEUS_UDF="machine_type=virtual machine|description=BAM test object; ToBeDeleted|phone=2038675309|location=Other|reg_by=NetId|reg_date=1981-11-16 00:00:00|user_name=NetId"

read -r -d '' PROTEUS_HOST_PAYLOAD <<-EOF
{
  "hostname": "<fqdn>",
  "cidr": "<subnet_cidr_for_new_ipaddress>",
  "reverse": true,
  "properties": "${PROTEUS_UDF}"
}
EOF
export PROTEUS_HOST_PAYLOAD

curl -H "Auth-Token: ${PROTEUS_API_AUTH_TOKEN}" \
     -H "Content-Type: application/json" \
     -X 'POST' \
     -d "${PROTEUS_HOST_PAYLOAD}" \
    'http://localhost:9393//v1/dns/bam-dev/ips'

```

### Create a New MAC Address

A MAC address create (POST) request has only one required value (`mac`).

If the optional parameter `macpool` is submitted, the MAC address will be created and associated with the specified MAC Pool.

A MAC address create request may look like this (replacing values in `<....>`):
```bash
# Construct payload
# Specify user-defined fields for Proteus Bluecat
export PROTEUS_UDF="machine_type=virtual machine|description=BAM test object; ToBeDeleted|phone=2038675309|location=Other|reg_by=NetId|reg_date=1981-11-16 00:00:00|user_name=NetId"

read -r -d '' PROTEUS_MAC_PAYLOAD <<-EOF
{
 "mac": "<mac_address>",
 "macpool": <optional_integer_value_of_macpool_object>,
 "properties": "${PROTEUS_UDF}"
}
EOF
export PROTEUS_MAC_PAYLOAD

curl -H "Auth-Token: ${PROTEUS_API_AUTH_TOKEN}" \
     -H "Content-Type: application/json" \
     -X 'POST' \
     -d "${PROTEUS_MAC_PAYLOAD}" \
    'http://localhost:9393//v1/dns/bam-dev/macs'
```

## Authors

 - E Camden Fisher (camden.fisher@yale.edu)
 - Tenyo Grozev (tenyo.grozev@yale.edu)
 - Jose Andrade (jose.andrade@yale.edu)
 - Vincent Balbarin (vincent.balbarin@yale.edu)

 ## License

The contents of this repository are covered under a [GNU Affero General Public License](/LICENSE).

Copyright, 2017, Yale University