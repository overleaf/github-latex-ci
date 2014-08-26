BuildManager = require "./BuildManager"
RepositoryManager = require "./RepositoryManager"
settings = require "settings-sharelatex"
mountPoint = settings.internal.github_latex_ci.mountPoint

module.exports = BuildController =
	buildLatestCommit: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		RepositoryManager.getLatestCommit req.ghclient, repo, (error, sha) ->
			return next(error) if error?
			req.params.sha = sha
			BuildController.buildCommit(req, res, next)

	buildCommit: (req, res, next) ->
		{sha, owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.markBuildAsInProgress repo, sha, (error) ->
			return next(error) if error?
			# Build in the background
			BuildManager.buildCommit req.ghclient, repo, sha
			res.redirect "#{mountPoint}/repos/#{repo}/builds/#{sha}"
			
	listBuilds: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getBuilds repo, (error, builds) ->
			return next(error) if error?
			res.render "builds/list",
				repo: repo,
				builds: builds
				
	showBuild: (req, res, next) ->
		{sha, owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getBuild repo, sha, (error, build) ->
			return next(error) if error?
			BuildManager.getOutputFiles repo, sha, (error, outputFiles) ->
				return next(error) if error?
				res.render "builds/show",
					repo: repo,
					build: build,
					outputFiles: outputFiles
					
	downloadOutputFile: (req, res, next) ->
		{sha, owner, repo, path} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getOutputFileStream repo, sha, path, (error, s3res) ->
			return next(error) if error?
			res.header("Content-Length", s3res.headers['content-length'])
			s3res.pipe(res)
			
	latestPdfBadge: (req, res, next) ->	
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getLatestBuild repo, (error, build) ->
			return next(error) if error?
			res.header("Content-Type", "image/svg+xml")
			res.render "badges/pdf.jade",
				build: build
