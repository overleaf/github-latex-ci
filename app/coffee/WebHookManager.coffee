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
	