settings = require "settings-sharelatex"
mongojs = require "mongojs"
db = mongojs.connect(settings.mongo.url, ["githubWebHooks"])
module.exports =
	db: db
	ObjectId: mongojs.ObjectId
