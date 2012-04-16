# Authenticate and authorize using Github account

QS        = require("querystring")
Request   = require("request")
logger    = require("../config/logger")
server    = require("../config/server")


# Send browser here to authenticate
server.get "/authenticate", (req, res, next)->
  redirect_uri = "http://#{req.headers.host}/oauth/callback"
  redirect_uri += "?return_to=#{req.query.return_to}" if req.query.return_to
  url = "https://github.com/login/oauth/authorize?" +
    QS.stringify(client_id: process.env.GITHUB_CLIENT_ID, redirect_uri: redirect_uri, scope: "repo")
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
        token:        token

      team_id = process.env.GITHUB_TEAM_ID
      logins = process.env.GITHUB_LOGINS
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
            logger.info "#{login} logged in successfully"
            log_in(user)
          else
            fail(user)
      else if logins
        # Authorization based on Github login
        if logins.split(/\s+/).indexOf(login) >= 0
          logger.info "#{login} logged in successfully"
          log_in(user)
        else
          fail(user)
      else
        # Default is to deny all
        fail(user)

  log_in = (user)->
    logger.debug "Logged in", user
    # Set the user cookie for the session
    res.cookies.set "user", JSON.stringify(user), signed: true
    # We use this to redirect back to where we came from
    res.redirect unescape(req.query.return_to || "/")

  fail = (user)->
    logger.debug "Access denied for", user
    req.flash "error", "You are not authorized to access this application"
    # Can't redirect back to protected resource, only place to go is home
    res.redirect "/"


 # Logout
 server.get "/logout", (req, res, next)->
   res.cookies.set "user"
   res.redirect "/"

