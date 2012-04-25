tokens = process.env.VANITY_TOKEN?.split(/\s+/)

# Looks for authentication header
authenticate = (req, res, next)->
  unless tokens
    next()
    return

  token = req.query.access_token || req.body.access_token
  unless token
    authorization = req.headers['authorization']
    if authorization
      [scheme, maybe_token] = authorization.split(/\s+/)
      token = maybe_token if scheme == "Bearer"

  if ~tokens.indexOf(token)
    next()
  else # Unauthorized
    res.send 401, "WWW-Authenticate": "Bearer"


module.exports = authenticate
