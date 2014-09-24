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
