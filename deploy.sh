#!/bin/sh
# Ref: https://gohugo.io/hosting-and-deployment/hosting-on-github/

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Build the project.
hugo -t archie

