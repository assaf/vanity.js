# Authenticate and authorize using Github account

QS        = require("querystring")
Request   = require("request")
logger    = require("../config/logger")
server    = require("../config/server")


# Send browser here to authenticate
server.get "/authenticate", (req, res, next)->
  redirect_uri = "http://#{req.headers.host}/oauth/callback"
  url = "https://github.com/login/oauth/authorize?" +
    QS.stringify(client_id: process.env.GITHUB_CLIENT_ID, redirect_uri: redirect_uri)
  res.redirect url


# OAuth callback
server.get "/oauth/callback", (req, res, next)->
  params =
    url: "https://github.com/login/oauth/access_token"
    json:
      code:           req.query.code
      client_id:      process.env.GITHUB_CLIENT_ID
      client_secret:  process.env.GITHUB_CLIENT_SECRET
  Request.post params, (error, response, json)->
    # If we got OAuth error, just show it.  Not user friendly.
    if json && json.error
      error = new Error(json.error)
    return next(error) if error

    url = "https://api.github.com/user?access_token=#{json.access_token}"
    Request.get url, (error, response, body)->
      return next(error) if error
      user = JSON.parse(body)
      user = # we only use these values
        login:        user.login
        name:         user.name
        gravatar_id:  user.gravatar_id
      # Set the user cookie
      res.cookies.set "user", JSON.stringify(user), signed: true
      # Redirect back to where we came from
      return_to = req.cookies.get("return_to") || "/"
      res.cookies.set "return_to"
      res.redirect return_to

 # Logout
 server.get "/logout", (req, res, next)->
   res.cookies.set "user"
   res.redirect "/"
