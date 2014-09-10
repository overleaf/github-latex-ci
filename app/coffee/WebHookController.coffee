logger = require "logger-sharelatex"
WebHookManager = require "./WebHookManager"
RepositoryManager = require "./RepositoryManager"
BuildManager = require "./BuildManager"

settings = require "settings-sharelatex"
{mountPoint} = settings.internal.github_latex_ci

module.exports = WebHookController =
	createHook: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		logger.log repo: repo, "creating web hook"
		WebHookManager.createWebHook req.ghclient, repo, (error, response) ->
			return next(error) if error?
			RepositoryManager.saveWebHook repo, response.id, (error) ->
				return next(error) if error?
				logger.log repo: repo, hook_id: response.id, "created web hook"
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
					req.session.destroy()
					res.redirect("#{mountPoint}/repos")
					
	webHookEvent: (req, res, next) ->
		body = ""
		req.setEncoding "utf8"
		req.on "data", (chunk) -> body += chunk
		req.on "end", ->
			valid = WebHookManager.verifyWebHookEvent req.headers['x-hub-signature'], body
			if !valid
				res.status(403).end()
			else if req.headers['x-github-event'] != "push"
				logger.log event: req.headers['x-github-event'], "webhook event was not a push"
				res.status(200).end()
			else
				try
					data = JSON.parse(body)
				catch
					data = {}
				sha = data.after
				repo = data.repository.full_name
				logger.log repo: repo, commit: sha, "got push webhook request"
				RepositoryManager.setLatestCommit repo, sha, (error) ->
					return next(error) if error?
					BuildManager.startBuildingCommitInBackground req.ghclient, repo, sha, (error) ->
						return next(error) if error?
						res.status(200).end()
				
	