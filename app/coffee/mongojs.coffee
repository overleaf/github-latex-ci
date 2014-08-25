settings = require "settings-sharelatex"
mongojs = require "mongojs"
db = mongojs.connect(settings.mongo.url, ["githubWebHooks", "githubBuilds"])
module.exports =
	db: db
	ObjectId: mongojs.ObjectId
