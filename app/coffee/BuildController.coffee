BuildManager = require "./BuildManager"

module.exports = BuildController =
	buildRepo: (req, res, next) ->
		{sha, owner, repo} = req.params
		repo = "#{owner}/#{repo}"
		BuildManager.buildAndSaveRepo req.ghclient, repo, sha, (error) ->
			return next(error) if error?
			res.status(200).end()
