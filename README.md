github-latex-ci
===============

An automated LaTeX build service for compiling continuous compiling of github repositories.

Dependencies
------------

The ShareLaTeX Cloud Compiler (github-latex-ci) requires the following dependencies:

* [MongoDB](http://www.mongodb.org/)
* [Node.js](http://nodejs.org/)
* [The ShareLaTeX Compiler](https://github.com/sharelatex/clsi-sharelatex)
* [Grunt](http://gruntjs.com/) (Install with `npm install grunt-cli`).

Installation
------------

After ensuring you have MongoDB and Node.js installed and running, and have set up the [ShareLaTeX Compiler](https://github.com/sharelatex/clsi-sharelatex), you can download and run this repository:

Get the code from Github:

```
$ git clone https://github.com/sharelatex/github-latex-ci.git
```

Install the required dependencies:

```
$ npm install
```

Run it:

```
$ grunt run
```

FAQ
---

Q. Can I compile private repositories?

A. No. To keep things simple, we only support public repositories. These do not need any authentication logic, since we can fetch the files without needing to authentication ourselves to github. To support private repositories we would need to keep a record of your github OAuth login, and then provide our own login/authentication system to make sure only you could view the PDF. This is beyond the scope of the project at the moment.

Q. Do you support package X?

A. If it's not included in the compile environment by default, you can upload a package to your GitHub repository and the ShareLaTeX compiler will find it.
