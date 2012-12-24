async = require 'async2'
fs = require 'fs'
coffee = require 'coffee-script'
CoffeeTemplates = require 'coffee-templates'
CoffeeStylesheets = require 'coffee-stylesheets'
CoffeeSprites = require 'coffee-sprites'

module.exports = class CoffeeAssets
  @aggregate: (file, cb) ->
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

  @precompile: (file, compile, cb) ->
    s = ''
    type = (m=file.match(/\..+$/)) isnt null and m[0]
    CoffeeAssets.aggregate file, (err, out) ->
      cb err if err
      flow = new async()
      for k of out
        if typeof out[k] is 'string'
          flow.serial ->
            done = @
            compile type, out[k], (err, compiled) ->
              cb err if err
              s += compiled
              done err
            return
        else # object
          if out[k].directive is 'require'
            flow.serial ->
              done = @
              precompile out[k].file, compile, (err, compiled) ->
                cb err if err
                s += compiled
                done err
              return
      flow.finally (err) ->
        cb err, s
        return
      return
    return

  @compiler: (o) ->
    o = o or {}
    o.template_options = o.template_options or format: true
    o.stylesheet_options = o.stylesheet_options or format: true

    (type, data, done) ->
      switch type
        when '.js.coffee'
          done null, coffee.compile data, bare: true
        when '.html.coffee'
          js_fn = eval '(function(){'+coffee.compile(data, bare: true)+'})'
          engine = new CoffeeTemplates o.template_options
          mustache = engine.render js_fn
          js_fn = CoffeeTemplates.compile mustache
          # do i need to format the js better here?
          done null, js_fn.toString()
        when '.css.coffee'
          debugger
          js_fn = eval '(function(){'+coffee.compile(data, bare: true)+'})'
          engine = new CoffeeStylesheets o.stylesheet_options
          engine.render js_fn, (err, css) ->
            debugger
            done err, css
        else # .js, .css, undefined
          done null, data

  @precompile_templates: (path, o, cb) ->
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

  @digest: ->

  @minify: ->

  @gzip: ->

  @clean: ->

