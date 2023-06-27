#!/bin/bash

# Move to a known location and save as START_DIR.
cd "$(dirname "$(dirname "${0}")")" || exit 1
START_DIR="${PWD}"

# Ensure we exit if anything usingn a pipe ('|') fails.
set -e -o pipefail

# Get the latest tag from the GitHub API.
HOME_ASSISTANT_CORE_LATEST_TAG="$(curl -Ls https://api.github.com/repos/home-assistant/core/tags | jq '.[].name' | sed 's/"//g' | grep -Ev '[[:alpha:]]' | sort -V | tail -n 1)"

# If we haven't already checked out the repo, do so now.
if [[ ! -d core ]]; then

  # Clone the repo max-depth of 1 commit as we only need the latest.
  git clone --depth 1 --recursive https://github.com/home-assistant/core/

fi

# Ensure that the core directory gets cleaned up on exit.
trap "rm -rf "${START_DIR}/core"" EXIT

# Create a variable for the source directory we are using.
SRC_DIR="${START_DIR}/core/homeassistant/components/default_config"

# Check the source directory exists
test -d "${SRC_DIR}" || exit 1

# If we have a 'clone' directory then we are running via GitHub Actions
# so change to that directory to have a consistent path structure for the following code.
if [ -d clone ]; then
  cd clone
fi

# Clean out the old data if it exists.
if [[ -d custom_components ]]; then
  rm -rf custom_components
fi

# Create somewhere for our updated code to go.
mkdir -p custom_components/default_config
cd custom_components/default_config

# Copy over the upstream files
cp -Rpf "${START_DIR}/core/homeassistant/components/default_config" "${START_DIR}/custom_components"

# Add in required data for the component to get loaded
sed -i "2i \  \"version\": \"${HOME_ASSISTANT_CORE_LATEST_TAG}.1\"," "${START_DIR}/custom_components/default_config/manifest.json"

# Disable the 'cloud' integration.
sed -i '/cloud/d' "${START_DIR}/custom_components/default_config/manifest.json"

# Update hacs.json with the minimum homeassistant value for the latest release
sed -i "s/$(cat "${START_DIR}/hacs.json" | grep homeassistant | awk '{print $2}')/\"${HOME_ASSISTANT_CORE_LATEST_TAG}\"/" "${START_DIR}/hacs.json"