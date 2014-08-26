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
			"./WebHookManager": @WebHookManager = {}
		@callback = sinon.stub()
		@ghclient = "ghclient-stub"
	
	describe "getRepos", ->
		it "should return all personal and organisation repos", ->
			personalRepos = [{
				full_name: "me/repo1"
			}, {
				full_name: "me/repo2"
			}]
			
			orgs = [{ login: "org1" }, { login: "org2" }]
			org1Repos = [{
				full_name: "org1/repo1"
			}, {
				full_name: "org1/repo2"
			}]
			org2Repos = [{
				full_name: "org2/repo1"
			}, {
				full_name: "org2/repo2"
			}]
			
			@RepositoryManager._getPersonalRepos = sinon.stub().callsArgWith(1, null, personalRepos)
			@RepositoryManager._getOrgs = sinon.stub().callsArgWith(1, null, orgs)
			@RepositoryManager._getOrgRepos = (req, org, callback) ->
				if org == "org1"
					callback null, org1Repos
				else if org == "org2"
					callback null, org2Repos
				else
					throw "Unknown org"
			sinon.spy @RepositoryManager, "_getOrgRepos"
			
			@req = {}
			@res =
				render: sinon.stub()
				
			@RepositoryManager.getRepos @ghclient, @callback
			
			@callback
				.calledWith(null, personalRepos.concat(org1Repos).concat(org2Repos))
				.should.equal true
				
	describe "injectWebhookStatus", ->
		it "should set webhook = true on repos with webhooks", (done) ->
			repos = [{
				full_name: "me/repo1"
			}, {
				full_name: "me/repo2"
			}, {
				full_name: "me/repo3"
			}]
			
			@WebHookManager.getWebHooksForRepos = sinon.stub().callsArgWith(1, null, [{
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
