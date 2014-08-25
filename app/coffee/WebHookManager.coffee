{db, ObjectId} = require "./mongojs"

module.exports = WebHookManager =
	saveWebHook: (repo, id, secret, callback = (error) ->) ->
		db.githubWebHooks.update({
			repo: repo
		}, {
			hook_id: id,
			secret: secret
		}, {
			upsert: true
		}, callback)