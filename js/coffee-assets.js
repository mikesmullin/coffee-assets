// Generated by CoffeeScript 1.4.0
var CoffeeAssets, CoffeeScript, CoffeeSprites, CoffeeStylesheets, CoffeeTemplates, async, fs, mkdirp, path;

async = require('async2');

fs = require('fs');

path = require('path');

mkdirp = require('mkdirp');

CoffeeScript = require('coffee-script');

CoffeeScript.require = require;

CoffeeTemplates = require('coffee-templates');

CoffeeStylesheets = require('coffee-stylesheets');

CoffeeSprites = require('coffee-sprites');

module.exports = CoffeeAssets = (function() {

  function CoffeeAssets() {
    this.sandboxes = {};
    this.manifest = {};
    this.manifest_length = 0;
  }

  CoffeeAssets.prototype.parse_directives = function(file, cb) {
    var _this;
    _this = this;
    fs.exists(file, function(exists) {
      if (!exists) {
        return cb("" + file + " does not exist.");
      }
      fs.readFile(file, 'utf8', function(err, code) {
        var directives, lx;
        if (err) {
          return cb(err);
        }
        if (!_this.manifest[file]) {
          _this.manifest[file] = {};
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
          if (!_this.manifest[file][a[3]]) {
            _this.manifest[file][a[3]] = _this.manifest_length++;
          }
          return a[0];
        });
        directives.push(code.substr(lx, code.length - lx));
        return cb(null, directives);
      });
    });
  };

  CoffeeAssets.prototype.precompile = function(file, compile, cb, lvl) {
    var m, s, type, _this;
    if (lvl == null) {
      lvl = 0;
    }
    _this = this;
    s = '';
    type = (m = file.match(/\..+$/)) !== null && m[0];
    this.parse_directives(file, function(err, out) {
      var flow, k;
      if (err) {
        return cb(err);
      }
      flow = new async();
      for (k in out) {
        if (typeof out[k] === 'string') {
          (function(code) {
            return flow.serial(function() {
              s += _this.escape_literal(file, type, code);
              this();
            });
          })(out[k]);
        } else {
          if (out[k].directive === 'require') {
            (function(file2) {
              return flow.serial(function() {
                var done;
                done = this;
                _this.precompile(file2, compile, (function(err, compiled) {
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

  CoffeeAssets.prototype.escape_literal = function(file, type, code) {
    var div;
    div = (new Array((80 / 2) - 3)).join('-=') + '-';
    file = path.relative(process.cwd(), file);
    switch (type) {
      case '.js.coffee':
        return ("\n###" + div + "\n" + file + "\n  " + div + " ###\n\n") + code;
      case '.js':
        return ("\n`\n\n/*" + div + "\n" + file + "\n  " + div + "\n */\n\n") + code.replace(/\`/g, '\\`') + "\n`\n";
      case '.css.coffee':
      case '.html.coffee':
        return ("\ncomment '" + div + "\\n" + file + "\\n   " + div + "\\n'\n\n") + code;
      case '.css':
      case '.html':
        return "\ncomment '" + div + "\\n" + file + "\\n   " + div + "\\n'\nliteral " + (JSON.stringify("\n\n" + code + "\n")) + "\n";
    }
  };

  CoffeeAssets.prototype.compiler = function(o) {
    var _this = this;
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
          err.message += _this.excerpt(code, err.lineNumber, 5);
        }
        return done(err);
      }
    };
  };

  CoffeeAssets.prototype.excerpt = function(code, lineNumber, grab) {
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

  CoffeeAssets.prototype.precompile_all = function(basepath, o, cb) {
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
      done(null);
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

  CoffeeAssets.prototype.write = function(infile, outfile, data, manifest_path, cb) {
    var directive, file, manifest_file, read_manifest, write_manifest, write_outfile,
      _this = this;
    manifest_file = path.join(manifest_path, 'manifest.json');
    console.log({
      infile: infile,
      outfile: outfile,
      manifest_path: manifest_path
    });
    for (file in this.manifest) {
      for (directive in this.manifest[file]) {
        console.log({
          file: file,
          directive: directive,
          directive_file: this.manifest[file][directive]
        });
      }
    }
    cb(null);
    return;
    console.log(this.manifest);
    write_outfile = function() {
      outfile = path.join(manifest_path, outfile);
      mkdirp.sync(path.dirname(outfile));
      return fs.writeFile(outfile, data, 'utf8', function(err) {
        if (err) {
          return cb(err);
        }
        return read_manifest();
      });
    };
    read_manifest = function() {
      return fs.exists(manifest_file, function(exists) {
        if (exists) {
          return fs.readFile(manifest_file, 'utf8', function(err, str) {
            var json;
            if (err) {
              return cb(err);
            }
            json = JSON.parse(str);
            for (file in _this.manifest[file]) {
              json[file] = _this.manifest[file];
            }
            _this.manifest = json;
            return write_manifest();
          });
        }
      });
    };
    write_manifest = function() {
      return fs.writeFile(manifest_file, JSON.stringify(_this.manifest, null, 2), 'utf8', function(err) {
        if (err) {
          return cb(err);
        }
        return cb(null);
      });
    };
    return write_outfile();
  };

  CoffeeAssets.prototype.digest = function() {};

  CoffeeAssets.prototype.minify = function() {};

  CoffeeAssets.prototype.gzip = function() {};

  CoffeeAssets.prototype.clean = function() {};

  return CoffeeAssets;

})();
