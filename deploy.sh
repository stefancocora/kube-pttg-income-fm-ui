#!/usr/bin/env bash
set -e
[ -n "${DEBUG}" ] && set -x

GIT_COMMIT=${GIT_COMMIT:-$(git rev-parse --short HEAD)}
GIT_COMMIT=${GIT_COMMIT:0:7}

echo ${GIT_COMMIT} > GIT_COMMIT
echo "deploy triggered by commit : ${GIT_COMMIT} on repo: ${GIT_URL} on branch ${GIT_BRANCH}"
echo "I will deploy version: $VERSION"

# running kb8or
./scripts/deploy -e dev ./pttg-ip-fm-ui.yaml
