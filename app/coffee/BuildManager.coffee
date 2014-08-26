request = require "request"
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
async = require "async"
knox = require "knox"
{db, ObjectId} = require "./mongojs"

{url, mountPoint} = settings.internal.github_latex_ci

s3client = knox.createClient {
	key:    settings.s3.key
	secret: settings.s3.secret
	bucket: settings.s3.github_latex_ci_bucket
}

module.exports = BuildManager =
	buildCommit: (ghclient, repo, sha, callback = (error) ->) ->
		BuildManager._getCommit ghclient, repo, sha, (error, commit) ->
			return callback(error) if error?
			commit =
				message: commit.commit.message
				author:  commit.commit.author
			logger.log commit: commit, repo: repo, sha: sha, "building repo"
			BuildManager.compileCommit ghclient, repo, sha, (error, status, outputFiles) ->
				return callback(error) if error?
				BuildManager.saveCompile repo, sha, commit, status, outputFiles, callback

	compileCommit: (ghclient, repo, sha, callback = (error, status, outputFiles) ->) ->
		BuildManager._getTree ghclient, repo, sha, (error, tree) ->
			return callback(error) if error?
			BuildManager._createClsiRequest tree, (error, clsiRequest) ->
				return callback(error) if error?
				logger.log clsiRequest: clsiRequest, "sending CLSI request"
				BuildManager._sendClsiRequest repo, clsiRequest, (error, response) ->
					return callback(error) if error?
					logger.log response: response, "got CLSI response"
					callback(null, response?.compile?.status, response?.compile?.outputFiles)
	
	saveCompile: (repo, sha, commit, status, outputFiles, callback = (error) ->) ->
		BuildManager._saveBuildInDatabase repo, sha, commit, status, (error) ->
			return callback(error) if error?
			
			jobs = []
			for file in outputFiles
				do (file) ->
					jobs.push (callback) ->
						BuildManager._saveOutputFileToS3 repo, sha, file.url, callback
						
			async.parallelLimit jobs, 5, callback
			
	getBuilds: (repo, callback = (error, builds) ->) ->
		db.githubBuilds.find({
			repo: repo
		}).sort({
			"commit.author.date": -1
		}, callback)
		
	getBuild: (repo, sha, callback = (error, builds) ->) ->
		db.githubBuilds.find {
			repo: repo
			sha: sha
		}, (error, builds = []) ->
			return callback(error) if error?
			callback null, builds[0]
	
	getLatestBuild: (repo, callback = (error, build) ->) ->
		db.githubBuilds.find({
			repo: repo
		}).sort({
			"commit.author.date": -1
		}).limit 1, (error, builds) ->
			callback error, builds[0]
			
	markBuildAsInProgress: (repo, sha, callback = (error) ->) ->
		BuildManager._saveBuildInDatabase repo, sha, null, "in_progress", callback
	
	_getTree: (ghclient, repo, sha, callback = (error, tree) ->) ->
		ghclient.repo(repo).tree(sha, true, callback)
		
	_getCommit: (ghclient, repo, sha, callback = (error, commit) ->) ->
		ghclient.repo(repo).commit(sha, callback)

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
			
	_saveBuildInDatabase: (repo, sha, commit, status, callback = (error) ->) ->
		db.githubBuilds.update({
			repo: repo
			sha:  sha
		}, {
			$set:
				status: status
				commit: commit
		}, {
			upsert: true
		}, callback)
		
	_saveOutputFileToS3: (repo, sha, sourceUrl, callback = (error) ->) ->
		m = sourceUrl.match(/\/project\/[^\/]+\/output\/(.*)$/)
		name = m[1]
		name = "#{repo}/#{sha}/#{name}"

		logger.log url: sourceUrl, location: name, "saving output file"

		req = request.get sourceUrl
		req.on "response", (res) ->
			headers = {
				'Content-Length': res.headers['content-length']
				'Content-Type':   res.headers['content-type']
			}
			logger.log location: name, content_length: res.headers['content-length'], "streaming to S3"
			s3client.putStream res, name, headers, (error, s3Req) ->
				return callback(error) if error?
				s3Req.resume()
				s3Req.on "end", callback
				
	getOutputFiles: (repo, sha, callback = (error, files) ->) ->
		prefix = "#{repo}/#{sha}"
		logger.log prefix: prefix, "listing output files"
		s3client.list { prefix: prefix }, (error, data) ->
			return callback(error) if error?
			files = []
			for file in data.Contents
				files.push file.Key.slice(prefix.length + 1)
			callback null, files
			
	getOutputFileStream: (repo, sha, name, callback = (error, res) ->) ->
		path = "#{repo}/#{sha}/#{name}"
		s3client.getFile path, callback
