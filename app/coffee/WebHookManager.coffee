{db, ObjectId} = require "./mongojs"

settings = require "settings-sharelatex"
{publicUrl, mountPoint} = settings.internal.github_latex_ci

# Monkey patch in a delete hook method
Repo = require("octonode").repo
Repo::deleteHook = (id, cb) ->
	url = "/repos/#{@name}/hooks/#{id}"
	@client.del url, null, (err, s, b, h) ->
		return cb(err) if err
		if s isnt 204 then cb(new Error("Repo deleteHook error")) else cb null, b, h
		
module.exports = WebHookManager =
	saveWebHookToDatabase: (repo, id, secret, callback = (error) ->) ->
		db.githubWebHooks.update({
			repo: repo
		}, {
			$set:
				hook_id: id,
				secret: secret
		}, {
			upsert: true
		}, callback)
		
	removeWebHookFromDatabase: (repo, hook_id, callback = (error) ->) ->
		db.githubWebHooks.remove({
			repo: repo
			hook_id: hook_id
		}, callback)
		
	getWebHookForRepo: (repo, callback = (error, webhook) ->) ->
		db.githubWebHooks.find {
			repo: repo
		}, (error, webhooks = []) ->
			callback error, webhooks[0]
		
	getWebHooksForRepos: (repos, callback = (error, webhooks) ->) ->
		db.githubWebHooks.find({
			repo: { $in: repos }
		}, callback)

	createWebHook: (ghclient, repo, secret, callback = (error, response) ->) ->
		ghclient.repo(repo).hook({
			"name": "web",
			"active": true,
			"events": ["push"],
			"config": {
				"url": "#{publicUrl}#{mountPoint}/events",
				"content_type": "json",
				"secret": secret
			}
		}, callback)
		
	destroyWebHook: (ghclient, repo, webhook_id, callback = (error) ->) ->
		ghclient.repo(repo).deleteHook(webhook_id, callback)
	