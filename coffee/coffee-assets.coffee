fs = require 'fs'

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
          return ''+coffee.eval data
        when '.html.coffee'
          engine = new CoffeeTemplates o.template_options
          data = coffee.eval data
          data = engine.render data
          # do i want to compile down to .js functions?
          return ''+engine.compile data
        when '.css.coffee'
          engine = new CoffeeStylesheets o.stylesheet_options
          data = coffee.eval data
          return engine.render data
        else # .js, .css, undefined
          return data

  digest: ->

  minify: ->

  gzip: ->

  clean: ->

