logger = require "logger-sharelatex"
logger.initialize("github-latex-ci")

metrics = require "metrics-sharelatex"
metrics.initialize "github-latex-ci"

settings = require "settings-sharelatex"
{mountPoint, publicUrl} = settings.internal.github_latex_ci

express = require "express"
app = express()

app.use metrics.http.monitor(logger)

csrf = require("csurf")()
# We use forms to do POST requests, with a _csrf field. bodyParser takes
# care of parsing these to req.body._csrf
bodyParser = require("body-parser")

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
app.set("style", settings.style)

# Cookies and sessions.
fiveDaysInMilliseconds = 5 * 24 * 60 * 60 * 1000
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
		maxAge: fiveDaysInMilliseconds
		secure: settings.secureCookie
	proxy: settings.behindProxy
))

destroySession = (req, res, next) ->
	if req.session?
		req.session.destroy()
	next()

app.use(AuthenticationController.setupLoginStatus)

app.get("#{mountPoint}/", IndexController.index)

app.get("#{mountPoint}/login", AuthenticationController.login)
app.get("#{mountPoint}/auth",  AuthenticationController.auth)

app.get("#{mountPoint}/repos", csrf, AuthenticationController.requireLogin, RepositoryController.list)
app.get("#{mountPoint}/repos/:owner/:repo", csrf, RepositoryController.show)
app.get("#{mountPoint}/repos/:owner/:repo/git/blobs/:sha", RepositoryController.proxyBlob)

app.post("#{mountPoint}/repos/:owner/:repo/hook", bodyParser(), csrf, AuthenticationController.requireLogin, WebHookController.createHook)
app.post("#{mountPoint}/repos/:owner/:repo/hook/destroy", bodyParser(), csrf, AuthenticationController.requireLogin, WebHookController.destroyHook)
app.post("#{mountPoint}/events", destroySession, WebHookController.webHookEvent)

app.get("#{mountPoint}/repos/:owner/:repo/builds/:sha", BuildController.showBuild)
app.get("#{mountPoint}/repos/:owner/:repo/builds/latest/badge.svg", BuildController.latestPdfBadge)

# Note that ../output.pdf is a clever link which will redirect to the build page if there is no PDF,
# while ../raw/output.pdf will fail if the PDF is not there.
app.get("#{mountPoint}/repos/:owner/:repo/builds/latest/output.pdf", BuildController.downloadLatestBuild)
app.get regex = new RegExp("^#{mountPoint.replace('/', '\/')}\/repos\/([^\/]+)\/([^\/]+)\/builds\/([^\/]+)\/raw\/(.*)$"), (req, res, next) ->
		params = {
			owner: req.params[0]
			repo:  req.params[1]
			sha:   req.params[2]
			path:  req.params[3]
		}
		req.params = params
		next()
	, BuildController.downloadOutputFile
	
app.post("#{mountPoint}/repos/:owner/:repo/builds/latest", bodyParser(), csrf, AuthenticationController.requireLogin, BuildController.buildLatestCommit)

app.get "#{mountPoint}/status", destroySession, (req, res, next) ->
	res.send("github-latex-ci is alive")

port = settings.internal.github_latex_ci.port
host = settings.internal.github_latex_ci.host
app.listen port, host, (error) ->
	throw error if error?
	logger.log "github-latex-ci listening on #{host}:#{port}"