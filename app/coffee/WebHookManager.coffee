settings = require "settings-sharelatex"
{publicUrl, mountPoint} = settings.internal.github_latex_ci
crypto = require "crypto"
logger = require "logger-sharelatex"

# Monkey patch in a delete hook method
Repo = require("octonode").repo
Repo::deleteHook = (id, cb) ->
	url = "/repos/#{@name}/hooks/#{id}"
	@client.del url, null, (err, s, b, h) ->
		return cb(err) if err
		if s isnt 204 then cb(new Error("Repo deleteHook error")) else cb null, b, h
		
module.exports = WebHookManager =
	createWebHook: (ghclient, repo, callback = (error, response) ->) ->
		ghclient.repo(repo).hook({
			"name": "web",
			"active": true,
			"events": ["push"],
			"config": {
				"url": "#{publicUrl}#{mountPoint}/events",
				"content_type": "json",
				"secret": settings.github.webhook_secret
			}
		}, callback)
		
	destroyWebHook: (ghclient, repo, webhook_id, callback = (error) ->) ->
		ghclient.repo(repo).deleteHook(webhook_id, callback)
		
	verifyWebHookEvent: (header, body) ->
		hmac = crypto.createHmac('sha1', settings.github.webhook_secret)
		hmac.setEncoding("hex")
		hmac.write body
		hmac.end()
		hash = hmac.read().toString("hex")
		valid = (header == "sha1=#{hash}")
		logger.log hash: hash, header: header, valid: valid, "verifying body"
		return valid