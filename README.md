# CoffeeAssets

```coffeescript
it 'can import these asset files (stylesheets, sprites, templates, behaviors)'
it 'can reach any relative or abs path, even one not in includes. its based on __dirpath of current file only
    e.g. so ststic/app/ can reach into static/public/assets, or vendors, or view templates'
it 'deletes sprite images at the start?'
it 'appends images to the sprite file as-we-go?'
it 'can provide digest suffices'
it 'can build a manifest.json'
it 'can google closure'
it 'can gzip'
it 'accepts input paths array'
it 'accepts output path'
it 'accepts list of files to compile?' # or we do it like rails ...
it 'outputs to a single /static/public/assets dir, separate and disposable from other /static/public/* files'
it 'allows inclusion of /node_modules dir for require directive js assets'
it 'can compile sprites across all stylesheets'
it 'understands sprockets directives require, require_tree, and require_self'
```
