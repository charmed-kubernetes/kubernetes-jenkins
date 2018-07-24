#!/bin/bash
set -eu

# This script will generate a PR for upstream kubernetes(https://github.com/kubernetes/kubernetes) containing the
# latest commits from the https://github.com/juju-solutions/kubernetes fork.

# grab the commit history
GIT_HISTORY=$(git log --pretty=format:"%s %b - %aN <%aE> %ad" staging..master)

# NOTE there is a race condition here. If someone can sneak in a commit between when we capture the
# log and rebase the staging branch we could sneak in a commit with no message about it. The reason
# I don't get history after the merge is that I have no point of comparison after the rebase because
# master would be the same as staging and I don't know how to compare it to upstream.

# we do this by rebasing master to the staging branch and then generating a PR from staging to upstream
git checkout staging
git rebase master
git push

# build up the PR message
cat << EOF > pr_message.txt
Juju updates

**Release note**:
\`\`\`release-note
${GIT_HISTORY}
\`\`\`
EOF

# now generate the PR - note that this requires GITHUB_TOKEN set to an access token with repo permissions
hub pull-request --file pr_message.txt -b kubernetes:master
