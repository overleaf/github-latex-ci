logger = require "logger-sharelatex"
logger.initialize("github-latex-ci")

settings = require "settings-sharelatex"
mountPoint = settings.internal.github_latex_ci.mountPoint

express = require "express"
app = express()

session    = require('express-session')
RedisStore = require('connect-redis')(session)

redis = require('redis')
rclient = redis.createClient(settings.redis.web.port, settings.redis.web.host)
rclient.auth(settings.redis.web.password)

AuthenticationController = require "./app/js/AuthenticationController"
RepositoryController = require "./app/js/RepositoryController"

app.set('views', './app/views')
app.set('view engine', 'jade')

# Cookies and sessions.
yearInMilliseconds = 365 * 24 * 60 * 60 * 1000
app.use(session(
	store: new RedisStore({
		host: settings.redis.web.host,
		port: settings.redis.web.port,
		pass: settings.redis.web.password
	})
	secret: settings.security.sessionSecret,
	name: settings.cookieName,
	cookie:
		domain: settings.cookieDomain
		maxAge: 1 * yearInMilliseconds
		secure: settings.secureCookie
	proxy: settings.behindProxy
))

app.use("#{mountPoint}/login", AuthenticationController.login)
app.use("#{mountPoint}/auth",  AuthenticationController.auth)

app.use("#{mountPoint}/repos", AuthenticationController.requireLogin, RepositoryController.list)

port = settings.internal.github_latex_ci.port
host = settings.internal.github_latex_ci.host
app.listen port, host, (error) ->
	throw error if error?
	logger.log "github-latex-ci listening on #{host}:#{port}"