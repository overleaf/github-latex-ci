BuildManager = require "./BuildManager"

module.exports = BuildController =
	buildRepo: (req, res, next) ->
		{sha, owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.buildAndSaveRepo req.ghclient, repo, sha, (error) ->
			return next(error) if error?
			res.status(200).end()
			
	listBuilds: (req, res, next) ->
		{owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getBuilds req.ghclient, repo, (error, builds) ->
			return next(error) if error?
			res.render "builds/list",
				repo: repo,
				builds: builds
				
	showBuild: (req, res, next) ->
		{sha, owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.getBuild req.ghclient, repo, sha, (error, build) ->
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
