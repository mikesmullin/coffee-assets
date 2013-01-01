async = require 'async2'
fs = require 'fs'
path = require 'path'
CoffeeScript = require 'coffee-script'
CoffeeScript.require = require
CoffeeTemplates = require 'coffee-templates'
CoffeeStylesheets = require 'coffee-stylesheets'
CoffeeSprites = require 'coffee-sprites'

sandboxes = {}

module.exports = class CoffeeAssets
  @aggregate: (file, cb) ->
    fs.exists file, (exists) ->
      return cb "#{file} does not exist." unless exists
      fs.readFile file, 'utf8', (err, code) ->
        return cb err if err
        directives = []
        lx=0
        code = code.replace `/^(#|\/\/|\/\*)= *(require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm`, ->
          a=arguments
          directives.push code.substr lx, a[5]-lx # contents before
          directives.push # a directive to be processed later
            directive: a[2]
            file: a[3]
          lx = a[5]+a[0].length # move cursor after token
          return a[0]
        directives.push code.substr lx, code.length-lx # contents after
        return cb null, directives
      return
    return

  @precompile: (file, compile, cb, lvl=0) ->
    s = ''
    type = (m=file.match(/\..+$/)) isnt null and m[0]
    CoffeeAssets.aggregate file, (err, out) ->
      return cb err if err
      flow = new async()
      for k of out
        if typeof out[k] is 'string'
          ((code) -> flow.serial ->
            s += CoffeeAssets.escape_literal type, code
            @()
            return
          )(out[k])
        else # object
          if out[k].directive is 'require'
            ((file2) -> flow.serial ->
              done = @
              CoffeeAssets.precompile file2, compile, ((err, compiled) ->
                return cb err if err
                s += compiled
                done err
                return
              ), lvl+1
              return
            )(path.resolve(path.dirname(file), out[k].file))
      flow.finally (err) ->
        cb err if err
        if lvl is 0
          compile type, s, cb # return compiled output
        else
          cb null, s # return CoffeeScript
        return
      return
    return

  @escape_literal: (type, code) ->
    switch type
      when '.js.coffee', '.css.coffee', '.html.coffee'
        return code # as-is
      when '.js'
        return "\n`\n"+code.replace(/\`/g, '\\`')+"\n`\n" # escaped in CoffeeScript
      when '.css'
        return "\nliteral #{JSON.stringify(code)}\n" # escaped in CoffeeStylesheets
      when '.html'
        return "\nliteral #{JSON.stringify(code)}\n" # escaped in CoffeeTemplates

  @compiler: (o) ->
    o = o or {}
    o.render_options = o.render_options or format: true

    (type, code, done) ->
      try
        switch type
          when '.js.coffee'
            done null, CoffeeScript.compile code, bare: true
          when '.html.coffee'
            js_fn = eval '(function(){'+CoffeeScript.compile(code, bare: true)+'})'
            engine = new CoffeeTemplates o.render_options
            mustache = engine.render js_fn
            js_fn = CoffeeTemplates.compile mustache
            done null, js_fn.toString()
          when '.css.coffee'
            js_fn = eval '(function(){'+CoffeeScript.compile(code, bare: true)+'})'
            engine = new CoffeeStylesheets o.render_options
            if o.sprite_options
              engine.use new CoffeeSprites o.sprite_options
            engine.render js_fn, (err, css) ->
              done err, css
          else # .js, .css, undefined
            done null, code
      catch err
        err.lineNumber = err.lineNumber or (m=err.message.match(`/ on line (\d+)/`)) isnt null and m[1]
        err.message += CoffeeAssets.excerpt code, err.lineNumber, 5 if err.lineNumber
        done err

  @excerpt: (code, lineNumber, grab=5) ->
    start = lineNumber-(Math.floor(grab/2)+1)
    lines = code.split("\n")
    lines.splice(0, Math.max(0, start))
    lines = lines.slice(0,grab)
    digits = (start+grab).toString().length
    format = (new Array(digits+1)).join('0')
    for i of lines
      ln = (format+(start+parseInt(i,10)+1)).substr(digits*-1)
      lines[i] = ln+' '+lines[i]
    return "\n\n"+lines.join("\n")+"\n"

  # currently only used for templates
  @precompile_all: (basepath, o, cb) ->
    engine = new CoffeeTemplates o.render_options
    templates = {}
    walk = (basepath, cb, done) ->
      items = fs.readdirSync basepath
      dirs = []
      for i, item of items
        abspath = basepath+'/'+item
        if fs.statSync(abspath).isDirectory()
          dirs.push abspath
          walk abspath, cb
        else
          cb abspath
      done() if typeof done is 'function'
      return dirs

    walk basepath, ((file) -> # walk the directory hierarchy
      if file.match(/\.html\.coffee$/) isnt null
        key = path.resolve(file).slice(path.resolve(basepath, '..').length+1, -12)
        code = fs.readFileSync file
        js_fn = eval '(function(){'+CoffeeScript.compile(''+code, bare: true)+'})'
        mustache = engine.render js_fn
        templates[key] = CoffeeTemplates.compile mustache, false
    ), ->
      js_fn = CoffeeTemplates.compileAll templates, o.compile_options
      return cb null, js_fn.toString()

  @digest: ->

  @minify: ->

  @gzip: ->

  @clean: ->

