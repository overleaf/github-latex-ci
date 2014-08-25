github = require "octonode"
settings = require "settings-sharelatex"
logger = require "logger-sharelatex"
mountPoint = settings.internal.github_latex_ci.mountPoint

module.exports =
	login: (req, res, next = (error) ->) ->
		auth_url = github.auth.config({
			id:     settings.github.client_id,
			secret: settings.github.client_secret
		}).login(['user:email', 'read:org', 'repo:status', 'write:repo_hook'])
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
			github.auth.login code, (error, token) ->
				return next(error) if error?
				req.session.token = token
				res.send("Logged in!")
				
	requireLogin: (req, res, next = (error) ->) ->
		if req.session?.token?
			req.ghclient = github.client(req.session.token)
			next()
		else
			res.redirect("#{mountPoint}/login")