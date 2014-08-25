request = require "request"
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
async = require "async"
{db, ObjectId} = require "./mongojs"

{url, mountPoint} = settings.internal.github_latex_ci

module.exports = BuildManager =
	buildAndSaveRepo: (ghclient, repo, sha, callback = (error) ->) ->
		BuildManager.buildRepo ghclient, repo, sha, (error, status, outputFiles) ->
			return callback(error) if error?
			BuildManager.saveBuild repo, sha, status, outputFiles, callback

	buildRepo: (ghclient, repo, sha, callback = (error, status, outputFiles) ->) ->
		BuildManager._getTree ghclient, repo, sha, (error, tree) ->
			return callback(error) if error?
			BuildManager._createClsiRequest tree, (error, clsiRequest) ->
				return callback(error) if error?
				logger.log clsiRequest: clsiRequest, "sending CLSI request"
				BuildManager._sendClsiRequest repo, clsiRequest, (error, response) ->
					return callback(error) if error?
					logger.log response: response, "got CLSI response"
					callback(null, response?.compile?.status, response?.compile?.outputFiles)
	
	saveBuild: (repo, sha, status, outputFiles, callback = (error) ->) ->
		BuildManager._saveBuildInDatabase repo, sha, status, (error) ->
			return callback(error) if error?
			
			jobs = []
			for file in outputFiles
				do (file) ->
					jobs.push (callback) ->
						BuildManager._saveOutputFileToS3 repo, sha, file.url, callback
						
			async.parallelLimit jobs, 5, callback
	
	_getTree: (ghclient, repo, sha, callback = (error, tree) ->) ->
		ghclient.repo(repo).tree(sha, true, callback)
		
	_createClsiRequest: (tree, callback = (error, clsiRequest) ->) ->
		resources = []
		for entry in tree.tree or []
			resources.push {
				path: entry.path
				url:  entry.url.replace(/^https:\/\/api\.github\.com/, url + mountPoint)
			}
			
		# TODO: Make compiler and rootResourcePath configurable
		clsiRequest =
			compile:
				options:
					compiler: "pdflatex"
				rootResourcePath: "main.tex"
				resources: resources
	
		callback null, clsiRequest
		
	_sendClsiRequest: (repo, req, callback = (error, data) ->) ->
		repo = repo.replace(/\//g, "-")
		request.post {
			uri: "#{settings.apis.clsi.url}/project/#{repo}/compile"
			json: req
		}, (error, response, body) ->
			return callback(error) if error?
			callback null, body
			
	_saveBuildInDatabase: (repo, sha, status, callback = (error) ->) ->
		db.githubBuilds.update({
			repo: repo
			sha:  sha
		}, {
			$set:
				status: status
		}, {
			upsert: true
		}, callback)
		
	_saveOutputFileToS3: (repo, sha, sourceUrl, callback = (error) ->) ->
		logger.log repo: repo, sha: sha, url: sourceUrl, "TODO! saving output file"
		callback()