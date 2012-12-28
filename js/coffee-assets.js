// Generated by CoffeeScript 1.4.0
var CoffeeAssets, CoffeeScript, CoffeeSprites, CoffeeStylesheets, CoffeeTemplates, async, fs, path, sandboxes;

async = require('async2');

fs = require('fs');

path = require('path');

CoffeeScript = require('coffee-script');

CoffeeScript.require = require;

CoffeeTemplates = require('coffee-templates');

CoffeeStylesheets = require('coffee-stylesheets');

CoffeeSprites = require('coffee-sprites');

sandboxes = {};

module.exports = CoffeeAssets = (function() {

  function CoffeeAssets() {}

  CoffeeAssets.aggregate = function(file, cb) {
    fs.exists(file, function(exists) {
      if (!exists) {
        return cb("" + file + " does not exist.");
      }
      fs.readFile(file, 'utf8', function(err, code) {
        var directives, lx;
        if (err) {
          return cb(err);
        }
        directives = [];
        lx = 0;
        code = code.replace(/^(#|\/\/|\/\*)= *(require) *([\w\d\-.\/\\]+) *(\*\/)?$/gm, function() {
          var a;
          a = arguments;
          directives.push(code.substr(lx, a[5] - lx));
          directives.push({
            directive: a[2],
            file: a[3]
          });
          lx = a[5] + a[0].length;
          return a[0];
        });
        directives.push(code.substr(lx, code.length - lx));
        return cb(null, directives);
      });
    });
  };

  CoffeeAssets.precompile = function(file, compile, cb, lvl) {
    var m, s, type;
    if (lvl == null) {
      lvl = 0;
    }
    s = '';
    type = (m = file.match(/\..+$/)) !== null && m[0];
    CoffeeAssets.aggregate(file, function(err, out) {
      var flow, k;
      if (err) {
        return cb(err);
      }
      flow = new async();
      for (k in out) {
        if (typeof out[k] === 'string') {
          (function(code) {
            return flow.serial(function() {
              s += CoffeeAssets.escape_literal(type, code);
              this();
            });
          })(out[k]);
        } else {
          if (out[k].directive === 'require') {
            (function(file2) {
              return flow.serial(function() {
                var done;
                done = this;
                CoffeeAssets.precompile(file2, compile, (function(err, compiled) {
                  if (err) {
                    return cb(err);
                  }
                  s += compiled;
                  done(err);
                }), lvl + 1);
              });
            })(path.resolve(path.dirname(file), out[k].file));
          }
        }
      }
      flow["finally"](function(err) {
        if (err) {
          cb(err);
        }
        if (lvl === 0) {
          compile(type, s, cb);
        } else {
          cb(null, s);
        }
      });
    });
  };

  CoffeeAssets.escape_literal = function(type, code) {
    switch (type) {
      case '.js.coffee':
      case '.css.coffee':
      case '.html.coffee':
        return code;
      case '.js':
        return "\n`\n" + (code.replace('`', '\\`')) + "\n`\n";
      case '.css':
        return "\nliteral " + (JSON.stringify(code)) + "\n";
      case '.html':
        return "\nliteral " + (JSON.stringify(code)) + "\n";
    }
  };

  CoffeeAssets.compiler = function(o) {
    o = o || {};
    o.render_options = o.render_options || {
      format: true
    };
    return function(type, code, done) {
      var engine, js_fn, m, mustache;
      try {
        switch (type) {
          case '.js.coffee':
            return done(null, CoffeeScript.compile(code, {
              bare: true
            }));
          case '.html.coffee':
            js_fn = eval('(function(){' + CoffeeScript.compile(code, {
              bare: true
            }) + '})');
            engine = new CoffeeTemplates(o.render_options);
            mustache = engine.render(js_fn);
            js_fn = CoffeeTemplates.compile(mustache);
            return done(null, js_fn.toString());
          case '.css.coffee':
            js_fn = eval('(function(){' + CoffeeScript.compile(code, {
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
            return done(null, code);
        }
      } catch (err) {
        err.lineNumber = err.lineNumber || (m = err.message.match(/ on line (\d+)/)) !== null && m[1];
        if (err.lineNumber) {
          err.message += CoffeeAssets.excerpt(code, err.lineNumber, 5);
        }
        return done(err);
      }
    };
  };

  CoffeeAssets.excerpt = function(code, lineNumber, grab) {
    var digits, format, i, lines, ln, start;
    if (grab == null) {
      grab = 5;
    }
    start = lineNumber - (Math.floor(grab / 2) + 1);
    lines = code.split("\n");
    lines.splice(0, Math.max(0, start));
    lines = lines.slice(0, grab);
    digits = (start + grab).toString().length;
    format = (new Array(digits + 1)).join('0');
    for (i in lines) {
      ln = (format + (start + parseInt(i, 10) + 1)).substr(digits * -1);
      lines[i] = ln + ' ' + lines[i];
    }
    return "\n\n" + lines.join("\n") + "\n";
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
      var code, js_fn, key, mustache;
      if (file.match(/\.html\.coffee$/) !== null) {
        key = path.resolve(file).slice(path.resolve(basepath, '..').length + 1, -12);
        code = fs.readFileSync(file);
        js_fn = eval('(function(){' + CoffeeScript.compile('' + code, {
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
