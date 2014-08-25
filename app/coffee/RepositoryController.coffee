logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
async  = require "async"

{publicUrl, mountPoint} = settings.internal.github_latex_ci

module.exports = RepositoryController =
	list: (req, res, next) ->
		jobs = []
		repos = []
		
		jobs.push (callback) ->
			RepositoryController._getPersonalRepos req, (error, personalRepos) ->
				return callback(error) if error?
				repos.push.apply(repos, personalRepos)
				callback()
		
		RepositoryController._getOrgs req, (error, orgs) ->
			return next(error) if error?
			for org in orgs
				do (org) ->
					jobs.push (callback) ->
						RepositoryController._getOrgRepos req, org.login, (error, orgRepos) ->
							return callback(error) if error?
							repos.push.apply(repos, orgRepos)
							callback()
		
			async.series jobs, (error) ->
				return next(error) if error?
				res.render "repos/list", repos: repos
				
	
			
	_getOrgs: (req, callback = (error, orgs) ->) ->
		req.ghclient.me().orgs callback
		
	_getOrgRepos: (req, org, callback = (error, repos) ->) ->
		req.ghclient.org(org).repos callback
		
	_getPersonalRepos: (req, callback = (error, repos) ->) ->
		req.ghclient.me().repos callback