logger = require "logger-sharelatex"
WebHookManager = require "./WebHookManager"
crypto = require "crypto"

settings = require "settings-sharelatex"
{publicUrl, mountPoint} = settings.internal.github_latex_ci

module.exports = WebHookController =
	createHook: (req, res, next) ->
		repo = "#{req.params.owner}/#{req.params.repo}"
		secret = crypto.randomBytes(32).toString("hex")
		logger.log repo: repo, secret: secret, "creating web hook"
		WebHookController._createWebHook req, repo, secret, (error, response) ->
			return next(error) if error?
			WebHookManager.saveWebHook repo, response.id, secret, (error) ->
				return next(error) if error?
				logger.log repo: repo, hook_id: response.id, secret: secret, "created web hook"
				res.redirect("#{mountPoint}/repos")
	
	_createWebHook: (req, repo, secret, callback = (error, response) ->) ->
		req.ghclient.repo(repo).hook({
			"name": "web",
			"active": true,
			"events": ["push", "pull_request"],
			"config": {
				"url": "#{publicUrl}#{mountPoint}/events",
				"content_type": "json",
				"secret": secret
			}
		}, callback)	
	