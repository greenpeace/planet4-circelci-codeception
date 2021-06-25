#!/usr/bin/env bash
#
# This is used to turn a project that just has a tests/ directory
# into a valid codeception project that can be run.
#
# The use case is for the NRO project repos to just define:
#
#   .
#   └── tests
#       └── HomePageCept.php
#
# ... and to turn it into:
#
#   .
#   ├── codeception.yml
#   ├── _output
#   ├── _support
#   │   └── AcceptanceTester.php
#   ├── tests
#   │    └── HomePageCept.php
#   └── tests.suite.yml
#

set -eux

destination="${1:-}"

if [[ -z "$destination" ]]; then
  echo "Usage: $0 <destination directory>"
  exit 1
fi

rsync -av --ignore-existing /home/circleci/codeception/ "$destination"

git config --global user.email "${GIT_USER_EMAIL}"
git config --global user.name "CircleCI Bot"

git clone --depth 1 https://github.com/greenpeace/planet4-master-theme.git

rsync -av planet4-master-theme/tests/acceptance/ tests/

git clone --depth 1 https://github.com/greenpeace/planet4-plugin-gutenberg-blocks.git

rsync -av planet4-plugin-gutenberg-blocks/tests/acceptance/ tests/

WP_DB_USERNAME_DC=$(echo "${WP_DB_USERNAME}" | base64 -d)
WP_DB_PASSWORD_DC=$(echo "${WP_DB_PASSWORD}" | base64 -d)
WP_TEST_USER_DC=$(echo "${WP_TEST_USER_DC}" | base64 -d)
echo "$SQLPROXY_KEY" | base64 -d >/home/circleci/key.json
export GOOGLE_APPLICATION_CREDENTIALS="/home/circleci/key.json"
export WP_DB_USERNAME_DC
export WP_DB_PASSWORD_DC
export WP_TEST_USER_DC

activate-gcloud-account.sh

make -C .. prepare-helm

cloud_sql_proxy -instances="${GOOGLE_PROJECT_ID}:us-central1:${CLOUDSQL_INSTANCE}=tcp:3306" &

sleep 2

test_account_add.sh

codecept run --xml=junit.xml --html

test_account_remove.sh

rm -f /home/circleci/key.json
