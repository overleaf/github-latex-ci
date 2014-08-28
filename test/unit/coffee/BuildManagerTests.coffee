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
				s3: { key: "", secret: "", github_latex_ci_bucket: "" }
			"request": {}
			"./mongojs": {}
			"knox": @knox = createClient: () ->
			"js-yaml": require("js-yaml") # Slow so only load once
		@repo = "owner-id/repo-id"
		@sha  = "mock-sha"
		@ghclient = "mock-ghclient"
		@callback = sinon.stub()
	
	describe "compileCommit", ->
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
			@clsiReq = {
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
			@BuildManager._createClsiRequest = sinon.stub().callsArgWith(1, null, @clsiReq)
			@BuildManager._sendClsiRequest = sinon.stub().callsArgWith(2, null, @clsiRes)
			
			@BuildManager.compileCommit(@ghclient, @repo, @sha, @callback)
					
		it "should get the tree from Github", ->
			@BuildManager._getTree
				.calledWith(@ghclient, @repo, @sha)
				.should.equal true
		
		it "should send a request to the CLSI", ->
			@BuildManager._sendClsiRequest
				.calledWith(@repo, @clsiReq)
				.should.equal true
		
		it "should return the status and output files", ->
			@callback
				.calledWith(null, @clsiRes.compile.status, @clsiRes.compile.outputFiles)
				.should.equal true
				
	describe "saveCompile", ->
		beforeEach ->
			@BuildManager._saveBuildInDatabase = sinon.stub().callsArg(4)
			@BuildManager._saveOutputFileToS3 = sinon.stub().callsArg(3)
			
			@BuildManager.saveCompile @repo, @sha, @commit = {
				message: "message", author: "author"
			}, @status = "success", @outputFiles = [{
				"url": "http://localhost:3013/project/project-id/output/output.log",
				"type": "log"
			}, {
				"url": "http://localhost:3013/project/project-id/output/output.pdf",
				"type": "pdf"
			}], @callback
			
		it "should save the build in the database", ->
			@BuildManager._saveBuildInDatabase
				.calledWith(@repo, @sha, @commit, @status)
				.should.equal true
				
		it "should save each output file to S3", ->
			for outputFile in @outputFiles
				@BuildManager._saveOutputFileToS3
					.calledWith(@repo, @sha, outputFile.url)
					.should.equal true

	describe "_createClsiRequest", ->
		beforeEach ->
			@files = {}
			@BuildManager._getBlobContent = (url, callback) =>
				path = url.slice("https://example.com/".length)
				callback null, @files[path]
			
			@treeFromFiles = (files) ->
				tree = []
				for path, contents of files
					tree.push {
						path: path
						url:  "https://example.com/#{path}"
						type: "blob"
					}
				return tree: tree
			
		describe 'with a root document determined by \documentclass', ->
			beforeEach (done) ->
				@files["chapter1.tex"] = """
					Contents of chapter 1
				"""
				@files["thesis.tex"] = """
					% Confused it with a comment first lien
					\\documentclass{article}
					\\begin{document}
					Hello world
					\\end{document}
				"""
				@BuildManager._createClsiRequest @treeFromFiles(@files), (error, @request) =>
					done()
					
			it "should set the root document", ->
				@request.compile.rootResourcePath.should.equal "thesis.tex"
			
		describe 'with a compiler determined by % !TEX program = LuaLaTeX', ->
			beforeEach (done) ->
				@files["chapter1.tex"] = """
					Contents of chapter 1
				"""
				@files["thesis.tex"] = """
					\\documentclass{article}
					% !TEX program = LuaLaTeX
					\\begin{document}
					Hello world
					\\end{document}
				"""
				@BuildManager._createClsiRequest @treeFromFiles(@files), (error, @request) =>
					done()
					
			it "should set the root document", ->
				@request.compile.options.compiler.should.equal "lualatex"
				
		describe 'with a compiler and root resource overridden by .latex.yml', ->
			beforeEach (done) ->
				@files["chapter1.tex"] = """
					Contents of chapter 1
				"""
				@files["thesis.tex"] = """
					\\documentclass{article}
					% !TEX program = LuaLaTeX
					\\begin{document}
					Hello world
					\\end{document}
				"""
				@files[".latex.yml"] = """
					compiler:  pdfLaTeX
					root_file: chapter1.tex
				"""
				@BuildManager._createClsiRequest @treeFromFiles(@files), (error, @request) =>
					done()
					
			it "should set the root document", ->
				@request.compile.options.compiler.should.equal "pdflatex"
				@request.compile.rootResourcePath.should.equal "chapter1.tex"
