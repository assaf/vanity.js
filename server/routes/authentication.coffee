# Authenticate and authorize using Github account

QS        = require("querystring")
Request   = require("request")
logger    = require("../config/logger")
server    = require("../config/server")


# If set, only authorize members of this team
team_id = process.env.GITHUB_TEAM_ID
# If set, only authorize specified logins
logins = process.env.GITHUB_LOGINS?.split(/,\s*/)


# Send browser here to authenticate.
#
# Use return_to query parameter to tell browser which page to go back to after
# authentication.
server.get "/authenticate", (req, res, next)->
  # Pass return_to parameter to callback
  redirect_uri = "http://#{req.headers.host}/oauth/callback"
  redirect_uri += "?return_to=#{req.query.return_to}" if req.query.return_to
  # You need 'repo' scope to list team members
  scope = "repo" if team_id
  url = "https://github.com/login/oauth/authorize?" +
    QS.stringify(client_id: process.env.GITHUB_CLIENT_ID, redirect_uri: redirect_uri, scope: scope)
  # This takes us to Github
  res.redirect url


# OAuth callback
server.get "/oauth/callback", (req, res, next)->
  # Exchange OAuth code for access token
  params =
    url: "https://github.com/login/oauth/access_token"
    json:
      code:           req.query.code
      client_id:      process.env.GITHUB_CLIENT_ID
      client_secret:  process.env.GITHUB_CLIENT_SECRET
  Request.post params, (error, response, json)->
    return next(error) if error
    # If we got OAuth error, just show it.
    if json && json.error
      logger.warning json.error
      req.flash "error", json.error
      res.redirect "/"
      return

    # Get the user name and gravatar ID, so we can display those.
    token = json.access_token
    url = "https://api.github.com/user?access_token=#{token}"
    Request.get url, (error, response, body)->
      return next(error) if error
      { login, name, gravatar_id } = JSON.parse(body)
      user = # we only care for these fields
        name:         name
        login:        login
        gravatar_id:  gravatar_id

      if team_id
        # Easiest way to determine if user is member of a team:
        # "In order to list members in a team, the authenticated user must be a member of the team."
        # -- http://developer.github.com/v3/orgs/teams/
        url = "https://api.github.com/teams/#{team_id}/members?access_token=#{token}"
        Request.get url, (error, response, body)->
          return next(error) if error
          if response.statusCode == 200
            members = JSON.parse(body).map((m)-> m.login)
          if members && members.indexOf(login) >= 0
            log_in(user)
          else
            fail(user)
      else if logins
        # Authorization based on Github login
        if logins.indexOf(login) >= 0
          log_in(user)
        else
          fail(user)
      else
        # Default is to deny all
        fail(user)

  log_in = (user)->
    logger.info "#{user.login} logged in successfully"
    logger.debug "Logged in", user
    # Set the user cookie for the session
    res.cookies.set "user", JSON.stringify(user), signed: true
    # We use this to redirect back to where we came from
    res.redirect unescape(req.query.return_to || "/")

  fail = (user)->
    logger.warning "Access denied for", user
    req.flash "error", "You are not authorized to access this application"
    # Can't redirect back to protected resource, only place to go is home
    res.redirect "/"


 # Logout
 server.get "/logout", (req, res, next)->
   res.cookies.set "user"
   res.redirect "/"

