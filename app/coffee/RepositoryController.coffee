logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
request = require "request"

RepositoryManager = require "./RepositoryManager"

{publicUrl, mountPoint, userAgent} = settings.internal.github_latex_ci

module.exports = RepositoryController =
	list: (req, res, next) ->
		RepositoryManager.gitReposOnGithub req.ghclient, (error, repos) ->
			return next(error) if error?
			RepositoryManager.injectWebHookStatus repos, (error, repos) ->
				return next(error) if error?
				res.render "repos/list",
					active_repos: repos.filter (r) -> r.webhook
					other_repos: repos.filter (r) -> !r.webhook
					csrfToken: req.csrfToken()
				
	proxyBlob: (req, res, next) ->
		url = req.url
		url = url.slice(mountPoint.length)
		request.get({
			uri: "https://api.github.com#{url}",
			qs: {
				client_id: settings.github.client_id
				client_secret: settings.github.client_secret
			},
			headers:
				"Accept": "application/vnd.github.v3.raw"
				"User-Agent": userAgent
		}).pipe(res)
