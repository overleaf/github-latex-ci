sandboxedModule = require "sandboxed-module"
modulePath = "../../../app/js/RepositoryController"
sinon = require "sinon"
chai = require "chai"
chai.should()

describe "RespositoryController", ->
	beforeEach ->
		@RepositoryController = sandboxedModule.require modulePath, requires:
			"logger-sharelatex": @logger = { log: sinon.stub, error: sinon.stub() }
	
	describe "list", ->
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
			
			@RepositoryController._getPersonalRepos = sinon.stub().callsArgWith(1, null, personalRepos)
			@RepositoryController._getOrgs = sinon.stub().callsArgWith(1, null, orgs)
			@RepositoryController._getOrgRepos = (req, org, callback) ->
				if org == "org1"
					callback null, org1Repos
				else if org == "org2"
					callback null, org2Repos
				else
					throw "Unknown org"
			sinon.spy @RepositoryController, "_getOrgRepos"
			
			@req = {}
			@res =
				render: sinon.stub()
				
			@RepositoryController.list @req, @res
			
			@res.render
				.calledWith("repos/list", repos: personalRepos.concat(org1Repos).concat(org2Repos))
				.should.equal true
	