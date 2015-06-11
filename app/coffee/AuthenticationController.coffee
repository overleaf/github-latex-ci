github = require "octonode"
settings = require "settings-sharelatex"
logger = require "logger-sharelatex"
metrics = require "metrics-sharelatex"
request = require "request"
mountPoint = settings.internal.github_latex_ci.mountPoint
auth = github.auth.config({
	id:     settings.github.client_id,
	secret: settings.github.client_secret
})

module.exports =
	login: (req, res, next = (error) ->) ->
		auth_url = auth.login(['user:email', 'read:org', 'repo:status', 'admin:repo_hook'])
		req.session ||= {}
		req.session.state = auth_url.match(/&state=([0-9a-z]{32})/i)[1];
		logger.log state: req.session.state, url: auth_url, "redirecting to github login page"
		res.redirect(auth_url)
		
	auth: (req, res, next = (error) ->) ->
		if !req.query.state? or req.query.state != req.session?.state
			logger.log received_state: req.query.state, stored_state: req.session?.state, "/auth CSRF check failed"
			res.status(403).send()
		else
			code = req.query.code
			logger.log code: code, "getting access_token from github"
			auth.login code, (error, token) ->
				return next(error) if error?
				req.session.token = token
				res.redirect "#{mountPoint}/repos"
			
	setupLoginStatus: (req, res, next = (error) ->) ->

		baseRequest = request.defaults({
			headers: {'Accept':'application/vnd.github.moondragon-preview+json'}
		})
		if req.session?.token?
			res.locals.loggedIn = req.loggedIn = true
			req.ghclient = github.client(req.session.token, {request:request})
		else
			res.locals.loggedIn = req.loggedIn = false

			req.ghclient = github.client({id: settings.github.client_id, secret: settings.github.client_secret},{request:baseRequest})

		if !req.ghclient._buildUrl?
			req.ghclient._buildUrl = req.ghclient.buildUrl
			req.ghclient.buildUrl = () ->
				metrics.inc "github-api-requests"
				req.ghclient._buildUrl.apply(req.ghclient, arguments)

		next()
				
	requireLogin: (req, res, next = (error) ->) ->
		if req.loggedIn
			next()
		else
			res.redirect("#{mountPoint}/login")