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

  parse_directives: (file, cb) ->
    _this = @
    fs.exists file, (exists) ->
      return cb "#{file} does not exist." unless exists
      fs.readFile file, 'utf8', (err, code) ->
        return cb err if err
        _this.manifest[file] = length: 0, files: {} unless _this.manifest[file]
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
          _this.manifest[file].files[a[3]] = _this.manifest[file].length++ unless _this.manifest[file].files[a[3]]
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
          compile file, type, s, cb # return compiled output
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
        return "\n"+code # as-is in CoffeeScript
      when '.js'
        return "\n`\n"+code.replace(/\`/g, '\\`')+"\n`\n" # escaped in CoffeeScript
      when '.css.coffee', '.html.coffee'
        return "\n"+code # as-is in CoffeeScript
      when '.css', '.html'
        return "\nliteral #{JSON.stringify("\n"+code+"\n")}\n" # escaped in CoffeeStylesheets / CoffeeTemplates

  compiler: (o) ->
    o = o or {}
    o.render_options = o.render_options or {}

    (file, type, code, done) =>
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
            o.render_options.file = file
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
      done null if typeof done is 'function' # not specified during recursion
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

  write: (infile, outfile, compiled_output, manifest_path, cb) ->
    manifest_file = path.join manifest_path, 'manifest.json'

    write_outfile = ->
      mkdirp.sync path.dirname outfile
      fs.writeFile outfile, compiled_output, 'utf8', (err) ->
        return cb err if err
        #read_manifest()
        cb null

    ## we only read the manifest first to merge it
    ## with what we will be writing
    ## since we only write one output file at a time
    ## we only actually merge over the disk version
    ## on the current file
    ## since (assuming coffee-assets was used to precompile)
    ## we would now know something new about the file
    ## which was just parsed, and we are outputting
    #read_manifest = =>
    #  fs.exists manifest_file, (exists) => if exists
    #    fs.readFile manifest_file, 'utf8', (err, str) =>
    #      return cb err if err
    #      # update manifest for this particular file
    #      manifest = JSON.parse str
    #      # convert in-memory directives from a random-order object (for uniqueness)
    #      # to an ordered array (for storage and processing)
    #      directives = new Array @manifest[infile].length
    #      for directive, index of @manifest[infile]
    #        # directive paths must be named relative to manifest.json
    #        directives[index] = path.relative manifest_path, directive
    #      manifest[outfile] = directives
    #      # all files must be named relative to manifest.json
    #      outfile = path.relative manifest_path, outfile
    #      write_manifest()

    #write_manifest = =>
    #  fs.writeFile manifest_file, JSON.stringify(@manifest, null, 2), 'utf8', (err) ->
    #    return cb err if err
    #    cb null

    write_outfile()

  digest: ->

  minify: ->

  gzip: ->

  clean: ->

