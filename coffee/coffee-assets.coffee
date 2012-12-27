async = require 'async2'
fs = require 'fs'
path = require 'path'
coffee = require 'coffee-script'
CoffeeTemplates = require 'coffee-templates'
CoffeeStylesheets = require 'coffee-stylesheets'
CoffeeSprites = require 'coffee-sprites'

module.exports = class CoffeeAssets
  @aggregate: (file, cb) ->
    fs.exists file, (exists) ->
      return cb "#{file} does not exist." unless exists
      fs.readFile file, 'utf8', (err, data) ->
        return cb err if err
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
        return cb null, directives
      return
    return

  @precompile: (file, compile, cb) ->
    s = ''
    CoffeeAssets.aggregate file, (err, out) ->
      return cb err if err
      flow = new async()
      for k of out
        if typeof out[k] is 'string'
          ((data) -> flow.serial ->
            done = @
            type = (m=file.match(/\..+$/)) isnt null and m[0]
            compile type, data, (err, compiled) ->
              return cb err if err
              s += compiled
              done err
            return
          )(out[k])
        else # object
          if out[k].directive is 'require'
            ((file2) -> flow.serial ->
              done = @
              CoffeeAssets.precompile file2, compile, (err, compiled) ->
                return cb err if err
                s += compiled
                done err
              return
            )(path.resolve(path.dirname(file), out[k].file))
      flow.finally (err) ->
        return cb err, s
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
          done null, js_fn.toString()
        when '.css.coffee'
          js_fn = eval '(function(){'+coffee.compile(data, bare: true)+'})'
          engine = new CoffeeStylesheets o.stylesheet_options
          if o.sprite_options
            engine.use new CoffeeSprites o.sprite_options
          engine.render js_fn, (err, css) ->
            done err, css
        else # .js, .css, undefined
          done null, data

  @precompile_templates: (base, o, cb) ->
    engine = new CoffeeTemplates o.template_options
    templates = {}
    walk = (base, cb, done) ->
      items = fs.readdirSync base
      dirs = []
      for i, item of items
        abspath = base+'/'+item
        if fs.statSync(abspath).isDirectory()
          dirs.push abspath
          walk abspath, cb
        else
          cb abspath
      done() if typeof done is 'function'
      return dirs

    walk base, ((file) -> # walk the directory hierarchy
      if file.match(/\.html\.coffee$/) isnt null
        key = path.resolve(file).slice(path.resolve(base, '..').length+1, -12)
        data = fs.readFileSync file
        js_fn = eval '(function(){'+coffee.compile(''+data, bare: true)+'})'
        mustache = engine.render js_fn
        templates[key] = CoffeeTemplates.compile mustache, false
    ), ->
      js_fn = CoffeeTemplates.compileAll templates, o.template_options
      return cb null, js_fn.toString()

  @digest: ->

  @minify: ->

  @gzip: ->

  @clean: ->

