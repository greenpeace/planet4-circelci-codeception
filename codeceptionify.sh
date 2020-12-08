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

set -eu

destination="${1:-}"

if [[ -z "$destination" ]]; then
  echo "Usage: $0 <destination directory>"
  exit 1
fi

rsync \
	-av \
	--ignore-existing \
	/home/circleci/scripts/codeception-skeleton/ \
	"$destination"
