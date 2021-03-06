#!/bin/bash
# Smoke test our apt and rpm feeds in various dockerized distros.

if [[ ! -e "$LPF_PATH" ]]; then
  echo "This script requires the environment variable LPF_PATH - the location of 'linux-package-feeds' scripts to use." >&2
  echo "They come from https://github.com/OctopusDeploy/linux-package-feeds, distributed in TeamCity" >&2
  echo "  via 'Infrastructure / Linux Package Feeds'." >&2
  exit 1
fi
if [[ -z "$PUBLISH_LINUX_EXTERNAL" ]]; then
  echo 'This script requires the environment variable PUBLISH_LINUX_EXTERNAL - specify "true" to test the external public feed.' >&2
  exit 1
fi
if [[ -z "$OCTOPUS_CLI_SERVER" || -z "$OCTOPUS_CLI_API_KEY" || -z "$OCTOPUS_SPACE" || -z "$OCTOPUS_EXPECT_ENV" ]]; then
  echo -e 'This script requires the environment variables OCTOPUS_CLI_SERVER, OCTOPUS_CLI_API_KEY, OCTOPUS_SPACE, and'\
    '\nOCTOPUS_EXPECT_ENV - specifying an Octopus server for testing "list-environments", an API key to access it, the'\
    '\nSpace to search, and an environment name expected to be found there.' >&2
  exit 1
fi

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"


for DOCKER_IMAGE in $(cat "$LPF_PATH/test-env-docker-images.conf" | grep -o '^[^#]*' | tr -d '\r')
do
  if [[ "$DOCKER_IMAGE" == *rhel* ]]; then
    RHEL_OPTS='--env REDHAT_SUBSCRIPTION_USERNAME --env REDHAT_SUBSCRIPTION_PASSWORD'
  else
    RHEL_OPTS=''
  fi

  echo "== Testing in '$DOCKER_IMAGE' =="
  docker pull "$DOCKER_IMAGE" >/dev/null || exit
  docker run --rm \
    --hostname "octotestfeedpkg$RANDOM" \
    --volume "$(pwd):/working" --volume "$SCRIPT_DIR/test-linux-package-from-feed.sh:/test-linux-package-from-feed.sh" \
    --volume "$(realpath "$LPF_PATH"):/opt/linux-package-feeds" \
    --env PUBLISH_LINUX_EXTERNAL \
    --env OCTOPUS_CLI_SERVER --env OCTOPUS_CLI_API_KEY --env OCTOPUS_SPACE --env OCTOPUS_EXPECT_ENV \
    $RHEL_OPTS \
    "$DOCKER_IMAGE" bash -c 'cd /working && bash /test-linux-package-from-feed.sh' || exit
done
