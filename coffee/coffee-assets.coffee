module.exports = (->
  # constructor
  C = (o) ->
    # initialize defaults
    o.base = o.base or process.cwd()
    o.output = o.output or o.base+'/static/public/assets/'
    o.template_options = o.template_options or {}
    o.format = o.format or true
    o.globals = o.globals or {}
    o.stylesheet_options =
    o.format = o.format or true
    o.valid_ext = o.valid_ext or ['.css', '.css.coffee']
    o.globals = o.globals or {}
    o.sprite_options = o.sprite_options or {}
    o.image_path =  o.base+'/precompile/assets/sprites/'
    o.sprite_path = o.base+'/static/public/assets/'
    o.sprite_url =  '/assets/'
    o.valid_ext = ['.png']
    @o = o
    return

  # private methods
  fs = require 'fs'

  type_is_valid = (file, from_file=undefined) -> # ensure file type is the kind we're looking for
    ext = (file) -> (m=file.match(/\..+$/)) isnt null and m[0]
    type = ext file
    tr = type.split('.')[0]
    if typeof from_type is 'undefined'
      (tr is '.js' or tr is '.css') and tr
    else
      from_type = from_file and ext from_file
      ftr = from_type.split('.')[0]
      tr is ftr and ftr

  push = (precompiled, abspath, data) => # [compile and] push data onto aggregation
    switch type
      when '.js.coffee'
        CoffeeTemplates = require 'coffee-templates'
        engine = new CoffeeTemplates @o.template_options
      when '.css.coffee'
        CoffeeStylesheets = require 'coffee-stylesheets'
        engine = new CoffeeStylesheets @o.stylesheet_options
    switch type
      when '.js.coffee', '.css.coffee'
        coffee = =require 'coffee-script'
        debugger
        data = (coffee.eval data).toString()
    precompiled[abspath] += data

  precompile = (cb) ->
    try
      precompiled = {}
      for k, file of o.start
        type = (type_is_valid absfile) or
          throw "invalid file type for starting file \"#{absfile}\"."

        abspath = fs.existsSync file or
          throw "unable to find file #{file}."

        data = fs.readFileSync abspath, 'utf8'

        directives = []
        data = data.replace `/^(#|\/\/|\/\*)= *(require_self|require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm`, ->
          a=arguments
          directives.push
            context: a[1]
            directive: a[2]
            path: a[3]
          return ''

        # act on each directive
        for kk, directive of directives
          switch directive.directive
            when 'require_self'
              push precompiled, abspath, data

            when 'require'
              type = type_is_valid directive.path
              ext = ''
              possible_ext = [
                '.css'
                '.css.coffee'
                '.js'
                '.js.coffee'
              ]
              while possible_ext.length and not (sub_abspath = fs.existsSync directive.path+ext)
                ext = possible_ext.pop()
              unless sub_abspath
                throw "require directive was unable to locate file #{directive.path} within #{@o.include.join(', ')}."
              read_file sub_abspath
              push precompiled, abspath, data

      for file, data of precompiled
        #console.log "Writing file #{file}..."
        fs.writeFileSync file, data, 'utf8'

      cb()

      return true
    catch err
      return false

  # public static methods

  C.precompile_templates = (from, to, from_ext, to_ext) ->
    template = require_without_cache __dirname+'/'+infile
    CoffeeTemplates = require 'coffee-templates'
    engine = new CoffeeTemplates
      format: true
      globals: require_without_cache __dirname+'/precompile/views/server/helpers/application.coffee'
    html = engine[if render then 'render' else 'compile'] template
    fs.writeFileSync outfile, html, 'utf8'
    notify 'Coffeecup precompile', 'compiled ' + outfile
    cb() if typeof cb is 'function'

  C.precompile_stylesheets = (from, to, from_ext, to_ext) ->
    o.valid_ext = o.valid_ext or ['.js', '.js.coffee']

  C.precompile_javascripts = (from, to, from_ext, to_ext) ->

  C.minify = ->

  C.gzip = ->

  C.clean = ->

  return C
)()

