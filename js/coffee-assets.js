// Generated by CoffeeScript 1.4.0
var CoffeeAssets, CoffeeSprites, CoffeeStylesheets, CoffeeTemplates, async, coffee, fs, path;

async = require('async2');

fs = require('fs');

path = require('path');

coffee = require('coffee-script');

CoffeeTemplates = require('coffee-templates');

CoffeeStylesheets = require('coffee-stylesheets');

CoffeeSprites = require('coffee-sprites');

module.exports = CoffeeAssets = (function() {

  function CoffeeAssets() {}

  CoffeeAssets.aggregate = function(file, cb) {
    fs.exists(file, function(exists) {
      if (!exists) {
        return cb("" + file + " does not exist.");
      }
      fs.readFile(file, 'utf8', function(err, data) {
        var directives, lx;
        if (err) {
          return cb(err);
        }
        directives = [];
        lx = 0;
        data = data.replace(/^(#|\/\/|\/\*)= *(require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm, function() {
          var a;
          a = arguments;
          directives.push(data.substr(lx, a[5] - lx));
          directives.push({
            directive: a[2],
            file: a[3]
          });
          lx = a[5] + a[0].length;
          return a[0];
        });
        directives.push(data.substr(lx, data.length - lx));
        return cb(null, directives);
      });
    });
  };

  CoffeeAssets.precompile = function(file, compile, cb) {
    var s;
    s = '';
    CoffeeAssets.aggregate(file, function(err, out) {
      var flow, k;
      if (err) {
        return cb(err);
      }
      flow = new async();
      for (k in out) {
        if (typeof out[k] === 'string') {
          (function(data) {
            return flow.serial(function() {
              var done, m, type;
              done = this;
              type = (m = file.match(/\..+$/)) !== null && m[0];
              compile(type, data, function(err, compiled) {
                if (err) {
                  return cb(err);
                }
                s += compiled;
                return done(err);
              });
            });
          })(out[k]);
        } else {
          if (out[k].directive === 'require') {
            (function(file2) {
              return flow.serial(function() {
                var done;
                done = this;
                CoffeeAssets.precompile(file2, compile, function(err, compiled) {
                  if (err) {
                    return cb(err);
                  }
                  s += compiled;
                  return done(err);
                });
              });
            })(path.resolve(path.dirname(file), out[k].file));
          }
        }
      }
      flow["finally"](function(err) {
        return cb(err, s);
      });
    });
  };

  CoffeeAssets.compiler = function(o) {
    o = o || {};
    o.render_options = o.render_options || {
      format: true
    };
    return function(type, data, done) {
      var engine, js_fn, mustache;
      switch (type) {
        case '.js.coffee':
          return done(null, coffee.compile(data, {
            bare: true
          }));
        case '.html.coffee':
          js_fn = eval('(function(){' + coffee.compile(data, {
            bare: true
          }) + '})');
          engine = new CoffeeTemplates(o.render_options);
          mustache = engine.render(js_fn);
          js_fn = CoffeeTemplates.compile(mustache);
          return done(null, js_fn.toString());
        case '.css.coffee':
          js_fn = eval('(function(){' + coffee.compile(data, {
            bare: true
          }) + '})');
          engine = new CoffeeStylesheets(o.render_options);
          if (o.sprite_options) {
            engine.use(new CoffeeSprites(o.sprite_options));
          }
          return engine.render(js_fn, function(err, css) {
            return done(err, css);
          });
        default:
          return done(null, data);
      }
    };
  };

  CoffeeAssets.precompile_all = function(basepath, o, cb) {
    var engine, templates, walk;
    engine = new CoffeeTemplates(o.render_options);
    templates = {};
    walk = function(basepath, cb, done) {
      var abspath, dirs, i, item, items;
      items = fs.readdirSync(basepath);
      dirs = [];
      for (i in items) {
        item = items[i];
        abspath = basepath + '/' + item;
        if (fs.statSync(abspath).isDirectory()) {
          dirs.push(abspath);
          walk(abspath, cb);
        } else {
          cb(abspath);
        }
      }
      if (typeof done === 'function') {
        done();
      }
      return dirs;
    };
    return walk(basepath, (function(file) {
      var data, js_fn, key, mustache;
      if (file.match(/\.html\.coffee$/) !== null) {
        key = path.resolve(file).slice(path.resolve(basepath, '..').length + 1, -12);
        data = fs.readFileSync(file);
        js_fn = eval('(function(){' + coffee.compile('' + data, {
          bare: true
        }) + '})');
        mustache = engine.render(js_fn);
        return templates[key] = CoffeeTemplates.compile(mustache, false);
      }
    }), function() {
      var js_fn;
      js_fn = CoffeeTemplates.compileAll(templates, o.compile_options);
      return cb(null, js_fn.toString());
    });
  };

  CoffeeAssets.digest = function() {};

  CoffeeAssets.minify = function() {};

  CoffeeAssets.gzip = function() {};

  CoffeeAssets.clean = function() {};

  return CoffeeAssets;

})();
