sandboxedModule = require "sandboxed-module"
modulePath = "../../../app/js/WebHookController"
sinon = require "sinon"
chai = require "chai"
chai.should()

describe "WebHookController", ->
	beforeEach ->
		@WebHookController = sandboxedModule.require modulePath, requires:
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"./WebHookManager": @WebHookManager = {}
			"crypto": @crypto = {}
			"settings-sharelatex":
				internal: github_latex_ci: { publicUrl: "http://example.com", mountPoint: @mountPoint = "/github" }
	
	describe "createHook", ->
		beforeEach ->
			@hook_id = "hook-id"
			@WebHookManager.createWebHook = sinon.stub().callsArgWith(3, null, { id: @hook_id })
			@WebHookManager.saveWebHookToDatabase = sinon.stub().callsArg(3)
			@secret = "deadbeef"
			@crypto.randomBytes = sinon.stub().returns(new Buffer(@secret, "hex"))
			@repo = "owner/repo"
			@req =
				ghclient: "mock-ghclient"
				params:
					owner: @repo.split("/")[0]
					repo:  @repo.split("/")[1]
			@res =
				redirect: sinon.stub()
				
			@WebHookController.createHook @req, @res
		
		it "should send a request to Github to create the webhook", ->
			@WebHookManager.createWebHook
				.calledWith(@req.ghclient, @repo, @secret)
				.should.equal true
		
		it "should store the webhook in the database", ->
			@WebHookManager.saveWebHookToDatabase
				.calledWith(@repo, @hook_id, @secret)
				.should.equal true
		
		it "should redirect to the repo list page", ->
			@res.redirect
				.calledWith("#{@mountPoint}/repos")
				.should.equal true
