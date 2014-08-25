sandboxedModule = require "sandboxed-module"
modulePath = "../../../app/js/BuildManager"
sinon = require "sinon"
chai = require "chai"
chai.should()

describe "BuildManager", ->
	beforeEach ->
		@BuildManager = sandboxedModule.require modulePath, requires:
			"logger-sharelatex": @logger = { log: sinon.stub(), error: sinon.stub() }
			"settings-sharelatex":
				internal: github_latex_ci: { url: "http://example.com", mountPoint: @mountPoint = "/github" }
			"request": {}
		@repo = "owner-id/repo-id"
		@sha  = "mock-sha"
		@ghclient = "mock-ghclient"
		@callback = sinon.stub()
	
	describe "buildRepo", ->
		beforeEach ->
			@tree = {
				tree: [{
					path: "main.tex"
					url:  "https://api.github.com/repos/#{@repo}/git/blobs/#{@main_blob = "bedbc8228ccc23414c177b75a930c74c614a6e78"}"
				}, {
					path: "chapters/chapter1.tex"
					url:  "https://api.github.com/repos/#{@repo}/git/blobs/#{@chapter_blob = "41202e1f414e699050aa631ee06117f1d04260a7"}"
				}]
			}
			@clsiRes = {
				compile:
					status: "success"
					outputFiles: [{
						"url": "http://localhost:3013/project/project-id/output/output.log",
						"type": "log"
					}, {
						"url": "http://localhost:3013/project/project-id/output/output.pdf",
						"type": "pdf"
					}]
			}
			@BuildManager._getTree = sinon.stub().callsArgWith(3, null, @tree)
			@BuildManager._sendClsiRequest = sinon.stub().callsArgWith(2, null, @clsiRes)
			
			@BuildManager.buildRepo(@ghclient, @repo, @sha, @callback)
					
		it "should get the tree from Github", ->
			@BuildManager._getTree
				.calledWith(@ghclient, @repo, @sha)
				.should.equal true
		
		it "should send a request to the CLSI", ->
			@BuildManager._sendClsiRequest
				.calledWith(@repo, {
					compile:
						options:
							compiler: "pdflatex"
						rootResourcePath: "main.tex"
						resources: [{
							path: "main.tex"
							url:  "http://example.com/github/repos/#{@repo}/git/blobs/#{@main_blob = "bedbc8228ccc23414c177b75a930c74c614a6e78"}"
						}, {
							path: "chapters/chapter1.tex"
							url:  "http://example.com/github/repos/#{@repo}/git/blobs/#{@chapter_blob = "41202e1f414e699050aa631ee06117f1d04260a7"}"
						}]	
				})
				.should.equal true
		
		it "should return the status and output files", ->
			@callback
				.calledWith(null, @clsiRes.compile.status, @clsiRes.compile.outputFiles)
				.should.equal true
				
	describe "saveBuild", ->
		beforeEach ->
			@BuildManager._saveBuildInDatabase = sinon.stub().callsArg(3)
			@BuildManager._saveOutputFileToS3 = sinon.stub().callsArg(3)
			
			@BuildManager.saveBuild @repo, @sha, @status = "success", @outputFiles = [{
				"url": "http://localhost:3013/project/project-id/output/output.log",
				"type": "log"
			}, {
				"url": "http://localhost:3013/project/project-id/output/output.pdf",
				"type": "pdf"
			}], @callback
			
		it "should save the build in the database", ->
			@BuildManager._saveBuildInDatabase
				.calledWith(@repo, @sha, @status)
				.should.equal true
				
		it "should save each output file to S3", ->
			for outputFile in @outputFiles
				@BuildManager._saveOutputFileToS3
					.calledWith(@repo, @sha, outputFile.url)
					.should.equal true

