if !process.env.GITHUB_CLIENT_ID? or !process.env.GITHUB_CLIENT_SECRET?
	console.log """
		Please set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET environment variables
	"""
	process.exit(1)

if !process.env.AWS_ACCESS_KEY? or !process.env.AWS_SECRET_KEY?
	console.log """
		Please set AWS_ACCESS_KEY and AWS_SECRET_KEY environment variables
	"""
	process.exit(1)


module.exports =
	internal:
		github_latex_ci:
			mountPoint: "/github"
			url: "http://localhost:3021"
			publicUrl: "http://localhost:3021"
			host: "localhost"
			port: 3021
			userAgent: "sharelatex/github-latex-ci"
			
	apis:
		clsi:
			url: "http://localhost:3013"
			
	github:
		client_id:      process.env.GITHUB_CLIENT_ID
		client_secret:  process.env.GITHUB_CLIENT_SECRET
		webhook_secret: process.env.GITHUB_WEBHOOK_SECRET || "webhook_secret"
		
	redis:
		web:
			host: "localhost"
			port: "6379"
			password: ""
			
	mongo:
		url: 'mongodb://127.0.0.1/sharelatex'

	s3:
		key:    process.env.AWS_ACCESS_KEY
		secret: process.env.AWS_SECRET_KEY
		github_latex_ci_bucket: "sl-github-latex-ci-dev"
			
	security:
		sessionSecret: "banana"
		
	cookieName: "github-latex-ci.sid"
	cookieDomain: null
	secureCookie: false
	behindProxy:  false