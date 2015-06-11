assert = require("assert")
sandboxedModule = require "sandboxed-module"
modulePath = "../../../app/js/RepositoryManager"
sinon = require "sinon"
chai = require "chai"
chai.should()

describe "RespositoryController", ->
	beforeEach ->
		@RepositoryManager = sandboxedModule.require modulePath, requires:
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"settings-sharelatex":
				internal: github_latex_ci: { publicUrl: "http://example.com", mountPoint: "/github" }
			"./mongojs": {}
			"./WebHookManager": @WebHookManager = {}
		@callback = sinon.stub()
		@ghclient = {}
	
	describe "gitReposOnGithub", ->
		it "should return all personal and organisation repos", (done)->
			personalRepos = [{
				full_name: "me/repo1"
			}, {
				full_name: "me/repo2"
			}, {
				full_name: "org1/repo1"
			}, {
				full_name: "org1/repo2"
			}, {
				full_name: "org2/repo1"
			}, {
				full_name: "org2/repo2"
			}]
					
			@ghclient.me = ->
				return repos: (opts, cb)->
					cb(null, personalRepos)
				
			@RepositoryManager.gitReposOnGithub @ghclient, (err, returnedRepos)->
				assert.deepEqual returnedRepos, personalRepos
				assert.equal err, undefined
				done()
				
	describe "injectWebhookStatus", ->
		it "should set webhook = true on repos with webhooks", (done) ->
			repos = [{
				full_name: "me/repo1"
			}, {
				full_name: "me/repo2"
			}, {
				full_name: "me/repo3"
			}]
			
			@RepositoryManager.getRepos = sinon.stub().callsArgWith(1, null, [{
				repo: "me/repo1"
			}, {
				repo: "me/repo3"
			}])
			
			@RepositoryManager.injectWebHookStatus repos, (error, repos) ->
				repos.should.deep.equal [{
					full_name: "me/repo1"
					webhook: true
				}, {
					full_name: "me/repo2"
				}, {
					full_name: "me/repo3"
					webhook: true
				}]
				done()
