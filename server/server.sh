# This is an example script for running the Vanity.js server.
#
# It contains Github client ID and secret that you can use to authenticate
# against a test server running on localhost:3000.
export GITHUB_CLIENT_ID=8fa9b2a82cb28fb664a4
export GITHUB_CLIENT_SECRET=204093f4739fbe8e9b07cfa16b5cfd70fca5bf66
# Only accept Github users that are members of this team
export GITHUB_TEAM_ID=
# Only accept Github users with these logins; change this if your username is
# not the same as your Github login (e.g. alice,bob)
export GITHUB_LOGINS=${USER}
# API access token.
export VANITY_TOKEN=f5a42eb99341be4c21bf8419b00f3d8d9c4f4699
export VANITY_COOKIE_KEYS=9c7516780b8bc00b523c565bb20980ee0865dcfc

node server.js
