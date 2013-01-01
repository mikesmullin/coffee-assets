async = require 'async2'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
CoffeeScript = require 'coffee-script'
CoffeeScript.require = require
CoffeeTemplates = require 'coffee-templates'
CoffeeStylesheets = require 'coffee-stylesheets'
CoffeeSprites = require 'coffee-sprites'

module.exports = class CoffeeAssets
  constructor: ->
    @sandboxes = {}
    @manifest = {}
    @manifest_length = 0

  parse_directives: (file, cb) ->
    _this = @
    fs.exists file, (exists) ->
      return cb "#{file} does not exist." unless exists
      fs.readFile file, 'utf8', (err, code) ->
        return cb err if err
        _this.manifest[file] = {} unless _this.manifest[file]
        directives = []
        lx=0
        code = code.replace `/^(#|\/\/|\/\*)= *(require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm`, ->
          a=arguments
          directives.push code.substr lx, a[5]-lx # contents before
          directives.push # a directive to be processed later
            directive: a[2]
            file: a[3]
          lx = a[5]+a[0].length # move cursor after token
          # append to manifest
          _this.manifest[file][a[3]] = _this.manifest_length++ unless _this.manifest[file][a[3]]
          return a[0]
        directives.push code.substr lx, code.length-lx # contents after
        return cb null, directives
      return
    return

  precompile: (file, compile, cb, lvl=0) ->
    _this = @
    s = ''
    type = (m=file.match(/\..+$/)) isnt null and m[0]
    @parse_directives file, (err, out) ->
      return cb err if err
      flow = new async()
      for k of out
        if typeof out[k] is 'string'
          ((code) -> flow.serial ->
            s += _this.escape_literal file, type, code
            @()
            return
          )(out[k])
        else # object
          if out[k].directive is 'require'
            ((file2) -> flow.serial ->
              done = @
              _this.precompile file2, compile, ((err, compiled) ->
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

  escape_literal: (file, type, code) ->
    div = (new Array((80/2)-3)).join('-=')+'-'
    file = path.relative process.cwd(), file
    switch type
      when '.js.coffee'
        return "\n####{div}\n#{file}\n  #{div} ###\n\n"+code # as-is in CoffeeScript
      when '.js'
        return "\n`\n\n/*#{div}\n#{file}\n  #{div}\n */\n\n"+code.replace(/\`/g, '\\`')+"\n`\n" # escaped in CoffeeScript
      when '.css.coffee', '.html.coffee'
        return "\ncomment '#{div}\\n#{file}\\n   #{div}\\n'\n\n"+code # as-is in CoffeeScript
      when '.css', '.html'
        return "\ncomment '#{div}\\n#{file}\\n   #{div}\\n'\nliteral #{JSON.stringify("\n\n"+code+"\n")}\n" # escaped in CoffeeStylesheets / CoffeeTemplates

  compiler: (o) ->
    o = o or {}
    o.render_options = o.render_options or format: true

    (type, code, done) =>
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
        err.message += @excerpt code, err.lineNumber, 5 if err.lineNumber
        done err

  # for debugging
  excerpt: (code, lineNumber, grab=5) ->
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
  precompile_all: (basepath, o, cb) ->
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
      done null
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
      cb null, js_fn.toString()

  write: (infile, outfile, data, manifest_path, cb) ->
    # all manifest files must be relative to manifest.json
    manifest_file = path.join manifest_path, 'manifest.json'
    outfile = path.relative manifest_path, outfile
    @manifest[outfile] = @manifest[infile]; delete @manifest[infile] # rename infile to outfile
    for file of @manifest
      for directive of @manifest[file]
        @manifest[file][directive] = path.relative manifest_path, @manifest[file][directive]

    console.log @manifest

    write_outfile = ->
      outfile = path.join manifest_path, outfile
      mkdirp.sync path.dirname outfile
      fs.writeFile outfile, data, 'utf8', (err) ->
        return cb err if err
        read_manifest()

    read_manifest = =>
      fs.exists manifest_file, (exists) => if exists
        fs.readFile manifest_file, 'utf8', (err, str) =>
          return cb err if err
          # merge memory version over disk version
          json = JSON.parse str
          for file of @manifest[file]
            json[file] = @manifest[file]
          @manifest = json
          write_manifest()

    write_manifest = =>
      fs.writeFile manifest_file, JSON.stringify(@manifest, null, 2), 'utf8', (err) ->
        return cb err if err
        cb null

    write_outfile()

  digest: ->

  minify: ->

  gzip: ->

  clean: ->

