logger = require "logger-sharelatex"
WebHookManager = require "./WebHookManager"
RepositoryManager = require "./RepositoryManager"
crypto = require "crypto"

settings = require "settings-sharelatex"
{mountPoint} = settings.internal.github_latex_ci

module.exports = WebHookController =
	createHook: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		secret = crypto.randomBytes(32).toString("hex")
		logger.log repo: repo, secret: secret, "creating web hook"
		WebHookManager.createWebHook req.ghclient, repo, secret, (error, response) ->
			return next(error) if error?
			RepositoryManager.saveWebHook repo, response.id, secret, (error) ->
				return next(error) if error?
				logger.log repo: repo, hook_id: response.id, secret: secret, "created web hook"
				res.redirect("#{mountPoint}/repos")
				
	destroyHook: (req, res, next) ->
		{owner, repo} = req.params
		repo_name = "#{owner}/#{repo}"
		RepositoryManager.getRepo repo_name, (error, repo) ->
			return next(error) if error?
			WebHookManager.destroyWebHook req.ghclient, repo_name, repo.hook_id, (error) ->
				return next(error) if error?
				RepositoryManager.deleteRepo repo_name, (error) ->
					return next(error) if error?
					logger.log repo: repo_name, hook_id: repo.hook_id, "destroyed web hook"
					res.redirect("#{mountPoint}/repos")
	