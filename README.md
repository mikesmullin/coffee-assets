# Why CoffeeAssets?

**CoffeeAssets** will bulk compile [CoffeeTemplates](https://github.com/mikesmullin/coffee-templates), [CoffeeScript](http://coffeescript.org/), and [CoffeeStylesheets](https://github.com/mikesmullin/coffee-stylesheets) with support for [CoffeeSprites](https://github.com/mikesmullin/coffee-sprites).
Optionally aggregating these using [Sprockets](https://github.com/sstephenson/sprockets)-like `#= require ./../file` directives, minifying with [Google Closure](https://developers.google.com/closure/compiler/), suffixing a digest,
writing a `manifest.json`, and gzipping into the neat little production-quality packages you expect. Additionally, its
*incredibly quickly*, with no [slow](https://github.com/gradus/coffeecup) [transpilers](https://github.com/learnboost/stylus) inbetween.

Inspired by
 [buildr.npm](https://github.com/balupton/buildr.npm),
 [mincer](https://github.com/nodeca/mincer),
 [coffee-sprites](https://github.com/mikesmullin/coffee-sprites), and
 [coffee-shop](https://github.com/mikesmullin/coffee-shop).

## Quick Examples

For the most recent and comprehensive examples, see [CoffeeShop's Cakefile](https://github.com/mikesmullin/coffee-shop/blob/stable/skeleton/Cakefile).
