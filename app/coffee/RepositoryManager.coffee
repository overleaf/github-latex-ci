logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
async  = require "async"

module.exports = RepositoryManager =
	getRepos: (ghclient, callback = (error, repos) ->) ->
		jobs = []
		repos = []
		
		jobs.push (callback) ->
			RepositoryManager._getPersonalRepos ghclient, (error, personalRepos) ->
				return callback(error) if error?
				repos.push.apply(repos, personalRepos)
				callback()
		
		RepositoryManager._getOrgs ghclient, (error, orgs) ->
			return callback(error) if error?
			for org in orgs
				do (org) ->
					jobs.push (callback) ->
						RepositoryManager._getOrgRepos ghclient, org.login, (error, orgRepos) ->
							return callback(error) if error?
							repos.push.apply(repos, orgRepos)
							callback()
		
			async.series jobs, (error) ->
				return callback(error) if error?
				callback null, repos
		
	_getOrgs: (ghclient, callback = (error, orgs) ->) ->
		ghclient.me().orgs callback
		
	_getOrgRepos: (ghclient, org, callback = (error, repos) ->) ->
		ghclient.org(org).repos callback
		
	_getPersonalRepos: (ghclient, callback = (error, repos) ->) ->
		ghclient.me().repos callback