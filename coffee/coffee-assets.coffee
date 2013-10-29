async                = require 'async2'
fs                   = require 'fs'
path                 = require 'path'
path.xplat           = (b,s)->path.join.apply null,if s then [b].concat s.split '/' else b.split '/' # makes *nix paths cross-platform compatible
require_fresh        = (a)->delete require.cache[require.resolve a];require a
mkdirp               = require 'mkdirp'
CoffeeScript         = require 'coffee-script'
CoffeeTemplates      = require 'coffee-templates'
CoffeeStylesheets    = require 'coffee-stylesheets'
CoffeeSprites        = require 'coffee-sprites'
CoffeeObserver       = require 'coffee-observer'

module.exports = class CoffeeAssets
  constructor: (o) ->
    @observer = new CoffeeObserver
    @sandboxes    = {}
    @manifest     = {}
    o = o or {}
    o.asset_path = o.asset_path or 'static/public/assets'
    @o = o

  @notify: @observer.notify
  @child_process_loop: @observer.child_process_loop
  @watch: @observer.watch

  @path: path
  @require_fresh: require_fresh
  common_compiler: (compiler_options) -> (o) =>
    o.outfile = o.outfile.replace(/\.coffee$/, '')
    if (a = async.q[o.title]) and # the queue exists
      a.beginning_length > 0 and # has tasks in it
      (count = a.beginning_length - a.processed) > 0 # and tasks are still processing
        @notify o.title, "will compile #{o.outfile} after #{count} task(s) complete", 'pending', false, true
    async.push o.title, (next) =>
      wrote = false
      o.cb = -> wrote = true; next.apply null, arguments
      async.delay 500, => if not wrote
        @notify o.title, "still compiling #{o.outfile}...", 'pending', false, true
      @precompile o.infile, @compiler(compiler_options), @write_manager o

  write_manager: (o) -> (err, compiled_output) =>
    o.cb = o.cb or ->
    return o.cb null, @notify o.title, err, 'failure', true, true if err
    @write o.infile, o.outfile, compiled_output, o.asset_path or @o.asset_path, (err) =>
      return o.cb null, @notify o.title, "unable to write #{o.outfile}. #{err}", 'failure', true, true if err
      @notify o.title, "wrote #{o.outfile}", 'success', false, true
      o.cb null

  write: (infile, outfile, compiled_output, manifest_path, cb) ->
    manifest_file = path.join manifest_path, 'manifest.json'
    mkdirp.sync path.dirname outfile
    fs.writeFile outfile, compiled_output, 'utf8', (err) ->
      return cb err if err
      cb null

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
    s = ''
    type = (m=file.match(/\..+$/)) isnt null and m[0]
    @parse_directives file, (err, out) =>
      return cb err if err
      flow = new async()
      for k of out
        if typeof out[k] is 'string'
          ((code) => flow.serial (next) =>
            s += @escape_literal file, type, code
            next()
          )(out[k])
        else # object
          if out[k].directive is 'require'
            ((file2) => flow.serial (next) =>
              @precompile file2, compile, ((err, compiled) ->
                return cb err if err
                s += compiled
                next null
              ), lvl+1
              return
            )(path.resolve(path.dirname(file), out[k].file))
      flow.finally (err) ->
        return cb err if err
        if lvl is 0
          compile file, type, s, cb # let compiler return output
        else
          cb null, s # return CoffeeScript
        return
      return
    return

  escape_literal: (file, type, code) ->
    div = (new Array((80/2)-3)).join('-=')+'-'
    file = path.relative process.cwd(), file
    switch type
      when '.js.coffee', '.json.coffee'
        return "\n"+code # as-is in CoffeeScript
      when '.js'
        return "\n"+code.replace(/\`/g, '\\`')+"\n" # escaped in CoffeeScript
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
          when '.json.coffee'
            _=(a,b)->c={};c[k]=a[k]for k of a;c[k]=b[k]for k of b;c # merge helper
            data = eval CoffeeScript.compile code, bare: true
            done null, JSON.stringify data, null, 2
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
    last_file = ''
    try
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
          last_file = file
          code = fs.readFileSync file
          js_fn = eval '(function(){'+CoffeeScript.compile(''+code, bare: true)+'})'
          mustache = engine.render js_fn
          templates[key] = mustache
      ), ->
        js_fn = CoffeeTemplates.compileAll templates, o.compile_options
        cb null, 'var templates='+js_fn.toString()
    catch err
      return cb """
      An error occurred while processing CoffeeTemplates #{last_file}:\n
      """+err.stack

  digest: ->

  minify: ->

  gzip: ->

  clean: ->

