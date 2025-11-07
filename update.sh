#!/bin/bash

set -exo 

bazel build //java/com/google/copybara:copybara_deploy.jar

SHA256SUM=$(sha256sum bazel-bin/java/com/google/copybara/copybara_deploy.jar | awk '{print $1}')

aws s3 cp bazel-bin/java/com/google/copybara/copybara_deploy.jar s3://applied-vehicle-os/copybara/${SHA256SUM}/copybara_deploy.jar --acl public-read --acl bucket-owner-full-control

echo "Copybara deployed to s3://applied-vehicle-os/copybara/${SHA256SUM}/copybara_deploy.jar"

echo "Change the COPYBARA_ARCHIVE_SHA in vehicle_os/repository_rules/deps.bzl to ${SHA256SUM} to use the new version."
