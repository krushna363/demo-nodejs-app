#!/bin/bash
## exit immediately on any command that fails
set -e

echo "Update & install OS packages..."
apt-get clean
apt-get -qq update
apt-get -qq -y install bc jq

# echo "Installing global npm packages..."
# npm install -g npm@latest cfn-create-or-update @cyclonedx/bom yarn@1.22.0



echo -e "OS Environment Vars\n" && env | sort

function build() {


  echo "Installing project node modules...."
  npm run install

  echo "Checking dependencies for security vulnerabilities..."
  set +e
  npm run audit --level moderate
  set -e

  echo "Checking outdated dependencies for security vulnerabilities..."
  set +e
  npm run outdated

  set -e

  echo "Running eslint..."
  npm run eslint

  echo "Running unit tests..."
  npm run coverage 
  echo "Running integration tests..."

  npm run integration

  set +e

  #echo "Pushing to SonarQube..."
  #sonar-scanner -Dsonar.host.url=$(aws ssm get-parameter --name "/cicd/sonarUrl" | jq -r '.Parameter.Value') \
  #    -Dsonar.projectName=$REPO \
  #    -Dsonar.projectKey=$REPO \
  #    -Dsonar.projectVersion=$CODEBUILD_RESOLVED_SOURCE_VERSION \
  #    -Dsonar.login=$(aws secretsmanager get-secret-value --secret-id /cicd/sonar/token | jq -r '.SecretString' | jq -r '.token') \
  #    -Dsonar.language=js \
  #    -Dsonar.sources=src \
  #    -Dsonar.tests=test \
  #    -Dsonar.javascript.lcov.reportPaths=coverage/unit/lcov.info

}
if [ "$ENV" = "dev" ] || [ "$ENV" = "nonprod" ]; then
  echo "Performing build..."
  build
fi

if [ -f build/pre-deploy.sh ]; then
  . ./build/pre-deploy.sh
fi

echo "Running ecs deploy..."
aws ecs update-service --cluster ecs-demo --service demo-nodejs-app --desired-count 2

if [ -f build/post-deploy.sh ]; then
  ./build/post-deploy.sh
fi

if [ "$ENV" != "prod" ]; then
  echo "Running system tests..."
  set +e
  npx coverage --system
  set -e
fi
