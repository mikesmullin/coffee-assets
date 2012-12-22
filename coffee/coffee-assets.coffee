module.exports = class CoffeeAssets
  constructor: (o) ->
    @base = process.cwd()
    o = o or {}
    o.include = o.include or [ # order is first-come, first-serve
      # main files
      @base+'/precompile/assets/behaviors/'
      @base+'/precompile/assets/stylesheets/'
      # vendor libs
      @base+'/precompile/vendor/assets/behaviors/' 
      @base+'/precompile/vendor/assets/stylesheets/'
      # node modules
      @base+'/node_modules/'
    ]
    o.output = o.output or base+'/static/public/assets/'
    o.sprites = o.sprites or {
      image_path:  @base+'/precompile/assets/sprites/'
      sprite_path: @base+'/static/public/assets/'
      sprite_url:  '/assets/'
    }
    o.template_options = o.template_options or {}
    o.stylesheet_options = o.stylesheet_options or {}
    o.start = o.start or [
      'application.js.coffee'
      'application.css.coffee'
    ]
    # TODO: make this actually be used instead of the repetition below
    o.pairs = o.pairs or {
      '.js': ['.js.coffee']
      '.css': ['.css.coffee']
    }

  aggregate: (cb) ->
    try
      fs = require 'fs'
      #path = require 'path'
      aggregated = {}

      # iterate on each starting file
      for k, file of o.start
        # validate file type
        type_is_valid = (file, from_file=undefined) ->
          ext = (file) -> (m=file.match(/\..+$/)) isnt null and m[0]
          type = ext file
          tr = type.split('.')[0]
          if typeof from_type is 'undefined'
            (tr is '.js' or tr is '.css') and tr
          else
            from_type = from_file and ext from_file
            ftr = from_type.split('.')[0]
            tr is ftr and ftr
        type = (type_is_valid absfile) or
          throw "invalid file type for starting file \"#{absfile}\"."

        # find starting file by looking in include directories (FIFO)
        find_file = (file) =>
          for suggestion of @o.include
            if fs.existsSync suggestion+file
              return suggestion+file
        abspath = find_file file or
          throw "unable to find file #{file}"

        # read starting file
        read_file = (abspath) =>
          data = fs.readFileSync abspath, 'utf8'

          # parse out sprockets directives
          directives = []
          data.replace `/^(#|\/\/|\/\*)= *(require_tree|require_self|require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm`, ->
            a=arguments
            directives.push
              context: a[1]
              directive: a[2]
              path: a[3]
            return

          # [compile and] push data onto aggregation
          push = (abspath, data) =>
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
            aggregated[abspath] += data

          # act on each directive
          included = false
          for kk, directive of directives
            switch directive.directive
              when 'require_tree'
                walk = (base, cb) ->
                  `var abspath=''`
                  items = fs.readdirSync base
                  dirs = []
                  for i, item of items
                    abspath = base+'/'+item
                    if fs.statSync(abspath).isDirectory()
                      dirs.push abspath
                      walk abspath, cb
                    else
                      cb abspath
                  dirs
                directive.path

                walk @base, (sub_abspath) ->
                  if type_is_valid sub_abspath, abspath
                    read_file sub_abspath

              when 'require_self'
                push abspath, data
                included = true

              when 'require'
                type = type_is_valid directive.path
                ext = ''
                possible_ext = [
                  '.css'
                  '.css.coffee'
                  '.js'
                  '.js.coffee'
                ]
                while possible_ext.length and not (sub_abspath = find_file directive.path+ext)
                  ext = possible_ext.pop()
                unless sub_abspath
                  throw "require directive was unable to locate file #{directive.path} within #{@o.include.join(', ')}."
                read_file sub_abspath

          unless included
            push abspath, data

          return data

      for file, data of aggregated
        console.log "Writing file #{file}..."
        fs.writeFileSync file, data, 'utf8'

      cb()

      return true
    catch err
      return false

  minify: ->

  gzip: ->

