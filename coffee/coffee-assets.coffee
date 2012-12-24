fs = require 'fs'
coffee = require 'coffee-script'
CoffeeTemplates = require 'coffee-templates'
CoffeeStylesheets = require 'coffee-stylesheets'
CoffeeSprites = require 'coffee-sprites'

module.exports = class CoffeeAssets
  aggregate: (file, cb) ->
    fs.readFile file, 'utf8', (err, data) ->
      cb err if err
      directives = []
      lx=0
      data = data.replace `/^(#|\/\/|\/\*)= *(require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm`, ->
        a=arguments
        directives.push data.substr lx, a[5]-lx # contents before
        directives.push # a directive to be processed later
          directive: a[2]
          file: a[3]
        lx = a[5]+a[0].length # move cursor after token
        return a[0]
      directives.push data.substr lx, data.length-lx # contents after
      cb null, directives
      return
    return

  precompile: (file, compile, cb), ->
    s = ''
    type = (m=file.match(/\..+$/)) isnt null and m[0]
    assets.aggregate file, (err, out) ->
      cb err if err
      for k of out
        if typeof out[k] is 'string'
          s += compile type, out[k]
        else # object
          if out[k].directive is 'require'
            precompile out[k].file, compile, (err, compiled) ->
              cb err if err
              s += compiled
            piece = out
      cb null, s
      return
    return

  compiler: (o) ->
    o = o or {}
    o.template_options = o.template_options or format: true
    o.stylesheet_options = o.stylesheet_options or format: true

    (type, data) ->
      switch type
        when '.js.coffee'
          js = coffee.eval data
          # do i need to format the js better here?
          return js.toString()
        when '.html.coffee'
          js_fn = coffee.eval '(->'+data+')'
          engine = new CoffeeTemplates o.template_options
          mustache = engine.render js_fn
          js_fn = CoffeeTemplates.compile mustache
          # do i need to format the js better here?
          return js_fn.toString()
        when '.css.coffee'
          js_fn = coffee.eval '(->'+data+')'
          engine = new CoffeeStylesheets o.stylesheet_options
          return engine.render data
        else # .js, .css, undefined
          return data

  precompile_templates: (path, o, cb) ->
    templates = {}
    # TODO: walk the in directory hierarchy
      # TODO: make object of coffee.eval js_fns with keys as their relative paths
      #       without file extensions
    # TODO: pass that object to CoffeeTemplates.compileAll and return a fn
    # TODO: convert that js_fn toString() and write to file templates.js
    js_fn = coffee.eval '(->'+data+')'
    engine = new CoffeeTemplates o.template_options
    templates['views/uesrs/...'] = mustache = engine.render js_fn
    js_fn = CoffeeTemplates.compileAll templates
    # do i need to format the js better here?
    return js_fn.toString()

  digest: ->

  minify: ->

  gzip: ->

  clean: ->

