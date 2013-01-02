# Why CoffeeAssets?

**CoffeeAssets** will bulk compile [CoffeeTemplates](https://github.com/mikesmullin/coffee-templates), [CoffeeScript](http://coffeescript.org/), and [CoffeeStylesheets](https://github.com/mikesmullin/coffee-stylesheets) with support for [CoffeeSprites](https://github.com/mikesmullin/coffee-sprites).
Optionally aggregating these using [Sprockets](https://github.com/sstephenson/sprockets)-like `#= require ./../file` directives, minifying with [Google Closure](https://developers.google.com/closure/compiler/), suffixing a digest,
writing a `manifest.json`, and gzipping into the neat little stable-quality packages you expect. Additionally, its
*incredibly fast*, with no meddling middleware dependencies, or [slow](https://github.com/gradus/coffeecup) [transpilers](https://github.com/learnboost/stylus) inbetween.

Inspired by
 [mincer](https://github.com/nodeca/mincer),
 [coffee-sprites](https://github.com/mikesmullin/coffee-sprites), and
 [buildr.npm](https://github.com/balupton/buildr.npm).

## Quick Examples

```coffeescript
# CoffeeScripts
watch [
    in: 'precompile'
    suffix: '/server.js.coffee'
    out: ''
  ,
    in: 'precompile/controllers/server'
    out: 'static/app/controllers'
  ,
    in: 'precompile/controllers/shared'
    out:  'static/public/assets/controllers'
  ,
    in: 'precompile/models/server'
    out: 'static/app/models'
  ,
    in: 'precompile/models/shared'
    out: 'static/public/assets/models'
  ,
    in: [
      'precompile/assets/behaviors'
      'precompile/vendor/assets'
    ]
    out: 'static/public/assets'
], '/**/*.{js,js.coffee}', (infile, outfile) ->
  assets.precompile infile, assets.compiler(), (err, compiled) ->
    return notify 'Cake CoffeeAssets CoffeeScript compiler', err, true, true if err
    write outfile.replace(/\.coffee$/,''), compiled

# CoffeeStylesheets
watch [
  in: [
    'precompile/assets/stylesheets'
    'precompile/vendor/assets'
  ],
  out: 'static/public/assets'
# filenames with underscore prefix are only compiled via require
], '/**/!(@(_))*.{css,css.coffee}', (infile, outfile) ->
  assets.precompile infile, assets.compiler(
    stylesheet_options:
      format: true
    sprite_options:
      image_path: 'precompile/assets/sprites/'
      sprite_path: 'static/public/assets/'
      sprite_url: '/assets/'
  ), (err, compiled) ->
    return notify 'Cake CoffeeAssets CoffeeStylesheets compiler', err, true, true if err
    write outfile.replace(/\.coffee/,''), compiled

# CoffeeTemplates (server-side; single function per file)
watch [
  in: 'precompile/views/server'
  out: 'static/app/views'
], '/**/*.html.coffee', (infile, outfile) ->
  assets.precompile infile, assets.compiler(
    template_options:
      format: true
  ), (err, compiled) ->
    return notify 'Cake CoffeeAssets CoffeeTemplates compiler', err, true, true if err
    write outfile.replace(/\.html.coffee/,'.js'), compiled

# CoffeeTemplates (client-side; multi-function aggregated to single file)
watch 'precompile/views/shared/**/*.html.coffee', ->
  # if ANY template file changes, ALL must be recompiled
  # because they are aggregated into a single templates.js file and function()
  assets.precompile_templates 'precompile/views/shared', {
    template_options:
      format: true
  }, (err, compiled) ->
    return notify 'Cake CoffeeAssets CoffeeTemplates compiler', err, true, true if err
    write 'static/public/assets/templates.js', compiled
```

For the most recent and comprehensive examples, see [CoffeeShop's Cakefile](https://github.com/mikesmullin/coffee-shop/blob/stable/skeleton/Cakefile).
