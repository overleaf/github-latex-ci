if !process.env.GITHUB_CLIENT_ID? or !process.env.GITHUB_CLIENT_SECRET?
	console.log """
		Please set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables
	"""
	process.exit(1)

module.exports =
	internal:
		github_latex_ci:
			mountPoint: "/github"
			publicUrl: "http://localhost:3020"
			host: "localhost"
			port: 3020
			
	github:
		client_id:     process.env.GITHUB_CLIENT_ID
		client_secret: process.env.GITHUB_CLIENT_SECRET
		
	redis:
		web:
			host: "localhost"
			port: "6379"
			password: ""
			
	mongo:
		url: 'mongodb://127.0.0.1/sharelatex'

			
	security:
		sessionSecret: "banana"
		
	cookieName: "github-latex-ci.sid"
	cookieDomain: null
	secureCookie: false
	behindProxy:  false