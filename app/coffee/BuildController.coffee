BuildManager = require "./BuildManager"
RepositoryManager = require "./RepositoryManager"
settings = require "settings-sharelatex"
mountPoint = settings.internal.github_latex_ci.mountPoint
mime = require('mime')
mimeWhiteList = ["application/pdf", "application/octet-stream", "text/plain"]
_ = require("lodash")

module.exports = BuildController =
	buildLatestCommit: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		RepositoryManager.getLatestCommitOnGitHub req.ghclient, repo, (error, sha) ->
			return next(error) if error?
			RepositoryManager.setLatestCommit repo, sha, (error) ->
				return next(error) if error?
				req.params.sha = sha
				BuildController.buildCommit(req, res, next)

	buildCommit: (req, res, next) ->
		{sha, owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.startBuildingCommitInBackground req.ghclient, repo, sha, (error) ->
			return next(error) if error?
			res.redirect "#{mountPoint}/repos/#{repo}"
			
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
			recomendedMime = mime.lookup(path)
			fileMime = if _.includes(mimeWhiteList, recomendedMime) then recomendedMime else "application/octet-stream"
			res.header "Content-Type", fileMime
			res.header("Content-Length", s3res.headers['content-length'])
			s3res.pipe(res)
			
	downloadLatestBuild: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		RepositoryManager.getLatestCommit repo, (error, sha) ->
			return next(error) if error?
			BuildManager.getBuild repo, sha, (error, build) ->
				return next(error) if error?
				if build? and build.status != "success"
					res.redirect "#{mountPoint}/repos/#{repo}"
				else
					res.redirect "#{mountPoint}/repos/#{repo}/builds/#{sha}/raw/output.pdf"
					
			
	latestPdfBadge: (req, res, next) ->	
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		RepositoryManager.getLatestCommit repo, (error, sha) ->
			return next(error) if error?
			BuildManager.getBuild repo, sha, (error, build) ->
				return next(error) if error?
				res.header("Content-Type", "image/svg+xml")
				res.render "badges/pdf.jade",
					build: build
