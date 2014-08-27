logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
async  = require "async"
WebHookManager = require "./WebHookManager"
{db, ObjectId} = require "./mongojs"

module.exports = RepositoryManager =
	gitReposOnGithub: (ghclient, callback = (error, repos) ->) ->
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
				
	injectWebHookStatus: (repos, callback = (error, repos) ->) ->
		RepositoryManager.getRepos repos.map((r) -> r.full_name), (error, webhooks) ->
			return callback(error) if error?
			webhooksDict = {}
			for webhook in webhooks
				webhooksDict[webhook.repo] = webhook
			for repo in repos
				if webhooksDict[repo.full_name]
					repo.webhook = true
			callback null, repos
	
	getLatestCommitOnGitHub: (ghclient, repo, callback = (error, sha) ->) ->
		ghclient.repo(repo).branch "master", (error, branch) ->
			return callback(error) if error?
			callback null, branch?.commit?.sha
		
	_getOrgs: (ghclient, callback = (error, orgs) ->) ->
		ghclient.me().orgs callback
		
	_getOrgRepos: (ghclient, org, callback = (error, repos) ->) ->
		ghclient.org(org).repos type: "public", callback
		
	_getPersonalRepos: (ghclient, callback = (error, repos) ->) ->
		ghclient.me().repos type: "public", callback
		
	saveWebHook: (repo, id, callback = (error) ->) ->
		db.githubRepos.update({
			repo: repo
		}, {
			$set:
				hook_id: id
		}, {
			upsert: true
		}, callback)
		
	deleteRepo: (repo, callback = (error) ->) ->
		db.githubRepos.remove({
			repo: repo
		}, callback)
		
	getRepo: (repo_name, callback = (error, repo) ->) ->
		db.githubRepos.find {
			repo: repo_name
		}, (error, repos = []) ->
			callback error, repos[0]
		
	getRepos: (repo_names, callback = (error, repos) ->) ->
		db.githubRepos.find({
			repo: { $in: repo_names }
		}, callback)
		
	setLatestCommit: (repo, sha, callback = (error) ->) ->
		db.githubRepos.update({
			repo: repo
		}, {
			$set: { latest_commit: sha }
		}, callback)
		
	getLatestCommit: (repo, callback = (error, sha) ->) ->
		db.githubRepos.find {
			repo: repo
		}, (error, repos = []) ->
			callback error, repos[0]?.latest_commit
