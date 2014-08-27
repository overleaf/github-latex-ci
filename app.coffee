logger = require "logger-sharelatex"
logger.initialize("github-latex-ci")

settings = require "settings-sharelatex"
{mountPoint, publicUrl} = settings.internal.github_latex_ci

express = require "express"
app = express()

session    = require('express-session')
RedisStore = require('connect-redis')(session)

redis = require('redis')
rclient = redis.createClient(settings.redis.web.port, settings.redis.web.host)
rclient.auth(settings.redis.web.password)

IndexController = require "./app/js/IndexController"
AuthenticationController = require "./app/js/AuthenticationController"
RepositoryController = require "./app/js/RepositoryController"
WebHookController = require "./app/js/WebHookController"
BuildController = require "./app/js/BuildController"

app.set('views', './app/views')
app.set('view engine', 'jade')

app.set("mountPoint", mountPoint)
app.set("publicUrl", publicUrl)

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

app.use(AuthenticationController.setupLoginStatus)

app.get("#{mountPoint}/", IndexController.index)

app.get("#{mountPoint}/login", AuthenticationController.login)
app.get("#{mountPoint}/auth",  AuthenticationController.auth)

app.get("#{mountPoint}/repos", AuthenticationController.requireLogin, RepositoryController.list)
app.get("#{mountPoint}/repos/:owner/:repo/git/blobs/:sha", RepositoryController.proxyBlob)

app.post("#{mountPoint}/repos/:owner/:repo/hook", AuthenticationController.requireLogin, WebHookController.createHook)
app.post("#{mountPoint}/repos/:owner/:repo/hook/destroy", AuthenticationController.requireLogin, WebHookController.destroyHook)

app.get("#{mountPoint}/repos/:owner/:repo/builds", BuildController.listBuilds)
app.get("#{mountPoint}/repos/:owner/:repo/builds/:sha", BuildController.showBuild)
app.get("#{mountPoint}/repos/:owner/:repo/builds/latest/badge.svg", BuildController.latestPdfBadge)
app.get regex = new RegExp("^#{mountPoint.replace('/', '\/')}\/repos\/([^\/]+)\/([^\/]+)\/builds\/([^\/]+)\/output\/(.*)$"), (req, res, next) ->
		params = {
			owner: req.params[0]
			repo:  req.params[1]
			sha:   req.params[2]
			path:  req.params[3]
		}
		req.params = params
		next()
	, BuildController.downloadOutputFile
	
app.post("#{mountPoint}/repos/:owner/:repo/builds/latest", AuthenticationController.requireLogin, BuildController.buildLatestCommit)

port = settings.internal.github_latex_ci.port
host = settings.internal.github_latex_ci.host
app.listen port, host, (error) ->
	throw error if error?
	logger.log "github-latex-ci listening on #{host}:#{port}"