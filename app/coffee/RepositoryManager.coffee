logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
async  = require "async"
WebHookManager = require "./WebHookManager"
{db, ObjectId} = require "./mongojs"

module.exports = RepositoryManager =
	gitReposOnGithub: (ghclient, callback = (error, repos) ->) ->
		pageSize = 100

		populateRepos = (page = 1, repos = [], cb)->
			ghclient.me().repos page: page, per_page: pageSize, (error, myRepos) ->
				return callback(error) if error?
				repos = repos.concat(myRepos)
				hasMore = myRepos.length == pageSize
				if hasMore
					populateRepos(++page, repos, cb)
				else
					cb(error, repos)

		populateRepos 1, [], (err, repos)->
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
