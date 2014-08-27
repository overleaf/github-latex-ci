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
			"./RepositoryManager": @RepositoryManager = {}
			"./BuildManager": @BuildManager = {}
			"settings-sharelatex":
				internal: github_latex_ci: { publicUrl: "http://example.com", mountPoint: @mountPoint = "/github" }
	
	describe "createHook", ->
		beforeEach ->
			@hook_id = "hook-id"
			@WebHookManager.createWebHook = sinon.stub().callsArgWith(2, null, { id: @hook_id })
			@RepositoryManager.saveWebHook = sinon.stub().callsArg(2)
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
				.calledWith(@req.ghclient, @repo)
				.should.equal true
		
		it "should store the webhook in the database", ->
			@RepositoryManager.saveWebHook
				.calledWith(@repo, @hook_id)
				.should.equal true
		
		it "should redirect to the repo list page", ->
			@res.redirect
				.calledWith("#{@mountPoint}/repos")
				.should.equal true
