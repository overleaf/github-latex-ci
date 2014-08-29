request = require "request"
logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
metrics = require "metrics-sharelatex"
async = require "async"
knox = require "knox"
yaml = require "js-yaml"
{db, ObjectId} = require "./mongojs"

{url, mountPoint, userAgent} = settings.internal.github_latex_ci

s3client = knox.createClient {
	key:    settings.s3.key
	secret: settings.s3.secret
	bucket: settings.s3.github_latex_ci_bucket
}

module.exports = BuildManager =
	startBuildingCommitInBackground: (ghclient, repo, sha, callback = (error) ->) ->
		BuildManager.markBuildAsInProgress repo, sha, (error) ->
			return callback(error) if error?
			# Build in the background
			BuildManager.buildCommit ghclient, repo, sha, (error) ->
				logger.error err:error, repo: repo, sha: sha, "background build failed"
			callback()

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
			
	getBuildAndOutputFiles: (repo, sha, callback = (error, build, outputFiles) ->) ->
		BuildManager.getBuild repo, sha, (error, build) ->
			return callback(error) if error?
			return callback(null, null, null) if !build?
			BuildManager.getOutputFiles repo, sha, (error, outputFiles) ->
				callback error, build, outputFiles
			
	getAllBuilds: (repo, callback = (error, builds) ->) ->
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
			
	markBuildAsInProgress: (repo, sha, callback = (error) ->) ->
		BuildManager._saveBuildInDatabase repo, sha, null, "in_progress", callback
	
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
	
	_getTree: (ghclient, repo, sha, callback = (error, tree) ->) ->
		ghclient.repo(repo).tree(sha, true, callback)
		
	_getCommit: (ghclient, repo, sha, callback = (error, commit) ->) ->
		ghclient.repo(repo).commit(sha, callback)

	_createClsiRequest: (tree, callback = (error, clsiRequest) ->) ->
		resources = []
		jobs = []
		
		docClassRootResourcePath = null
		ymlRootResourcePath = null
		texCompiler = null
		ymlCompiler = null
		
		logger.log tree: tree, "building CLSI request for Github tree"
		
		for entry in tree.tree or []
			do (entry) ->
				if entry.type == "blob"
					jobs.push (callback) ->
						if entry.path.match(/\.tex$/)
							BuildManager._getBlobContent entry.url, (error, content) ->
								return callback(error) if error?
								resources.push {
									path: entry.path,
									content: content
								}
								
								if content.match(/^\s*\\documentclass/m)
									docClassRootResourcePath = entry.path
									
								if (m = content.match(/\%\s*!TEX\s*(?:TS-)?program\s*=\s*(.*)$/m))
									texCompiler = BuildManager._canonicaliseCompiler(m[1])
									
								callback()
						else if entry.path == ".latex.yml"
							BuildManager._getBlobContent entry.url, (error, content) ->
								try
									data = yaml.safeLoad content
								catch
									data = {}
								ymlRootResourcePath = data['root_file']
								if data['compiler']?
									ymlCompiler = BuildManager._canonicaliseCompiler(data['compiler'])
								callback()
						else
							resources.push {
								path: entry.path
								url:  entry.url.replace(/^https:\/\/api\.github\.com/, url + mountPoint)
								modified: new Date(0) # The blob sha is a unique id for the content so cache forever
							}
							callback()
		
		async.series jobs, (error) ->
			return callback(error) if error?
			
			clsiRequest =
				compile:
					options:
						compiler: ymlCompiler or texCompiler or "pdflatex"
					rootResourcePath: ymlRootResourcePath or docClassRootResourcePath or "main.tex"
					resources: resources
		
			callback null, clsiRequest
			
	_canonicaliseCompiler: (compiler) ->
		COMPILERS = {
			'pdflatex': 'pdflatex'
			'latex':    'latex'
			'luatex':   'lualatex'
			'lualatex': 'lualatex'
			'xetex':    'xelatex'
			'xelatex':  'xelatex'
		}
		return COMPILERS[compiler.toString().trim().toLowerCase()] or "pdflatex"
		
	_getBlobContent: (url, callback = (error, content) ->) ->
		metrics.inc "github-api-requests"
		request.get {
			uri: url,
			qs: {
				client_id: settings.github.client_id
				client_secret: settings.github.client_secret
			},
			headers: {
				"Accept": "application/vnd.github.v3.raw"
				"User-Agent": userAgent
			}
		}, (error, response, body) ->
			callback error, body
		
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

