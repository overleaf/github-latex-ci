logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
metrics = require "metrics-sharelatex"
request = require "request"

RepositoryManager = require "./RepositoryManager"
BuildManager = require "./BuildManager"

{publicUrl, mountPoint, userAgent} = settings.internal.github_latex_ci

module.exports = RepositoryController =
	list: (req, res, next) ->
		RepositoryManager.gitReposOnGithub req.ghclient, (error, repos) ->
			return next(error) if error?
			RepositoryManager.injectWebHookStatus repos, (error, repos) ->
				return next(error) if error?
				res.render "repos/list",
					activeRepos: repos.filter (r) -> r.webhook
					otherRepos: repos.filter (r) -> !r.webhook
					csrfToken: req.csrfToken()
					
	show: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getAllBuilds repo, (error, allBuilds) ->
			return next(error) if error?
			RepositoryManager.getLatestCommit repo, (error, sha) ->
				return next(error) if error?
				BuildManager.getBuildAndOutputFiles repo, sha, (error, latestBuild, outputFiles) ->
					return next(error) if error?
					res.render "repos/show",
						repo: repo,
						builds: allBuilds,
						latestBuild: latestBuild,
						outputFiles: outputFiles,
						csrfToken: req.csrfToken()
				
	proxyBlob: (req, res, next) ->
		url = req.url
		url = url.slice(mountPoint.length)
		metrics.inc "github-api-requests"
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
