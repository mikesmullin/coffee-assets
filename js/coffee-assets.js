// Generated by CoffeeScript 1.4.0
var CoffeeAssets, CoffeeScript, CoffeeSprites, CoffeeStylesheets, CoffeeTemplates, async, child_process, fs, gaze, growl, mkdirp, path, require_fresh;

async = require('async2');

fs = require('fs');

path = require('path');

path.xplat = function(b, s) {
  return path.join.apply(null, s ? [b].concat(s.split('/')) : b.split('/'));
};

require_fresh = function(a) {
  delete require.cache[require.resolve(a)];
  return require(a);
};

mkdirp = require('mkdirp');

growl = require('growl');

gaze = require('gaze');

child_process = require('child_process');

async = require('async2');

CoffeeScript = require('coffee-script');

CoffeeTemplates = require('coffee-templates');

CoffeeStylesheets = require('coffee-stylesheets');

CoffeeSprites = require('coffee-sprites');

module.exports = CoffeeAssets = (function() {

  function CoffeeAssets(o) {
    this.sandboxes = {};
    this.manifest = {};
    this._titles = {};
    this._color_index = 0;
    this.colors = ['\u001b[33m', '\u001b[34m', '\u001b[35m', '\u001b[36m', '\u001b[31m', '\u001b[32m', '\u001b[1m\u001b[33m', '\u001b[1m\u001b[34m', '\u001b[1m\u001b[35m', '\u001b[1m\u001b[36m', '\u001b[1m\u001b[31m', '\u001b[1m\u001b[32m'];
    this.node_child = null;
    o = o || {};
    o.asset_path = o.asset_path || 'static/public/assets';
    this.o = o;
  }

  CoffeeAssets.path = path;

  CoffeeAssets.require_fresh = require_fresh;

  CoffeeAssets.prototype.notify = function(title, msg, image, err, show) {
    var prefix;
    if (typeof this._titles[title] === 'undefined') {
      this._titles[title] = this._color_index++;
    }
    if (err && typeof msg === 'object' && typeof msg.stack !== 'undefined') {
      msg = msg.stack;
    }
    if (show) {
      growl(msg, {
        image: path.xplat(__dirname, "/../images/" + image + ".png"),
        title: title
      });
    }
    msg = ('' + msg).replace(/[\r\n]+$/, '');
    prefix = "" + this.colors[this._titles[title]] + title + ":\u001b[0m ";
    console.log("" + prefix + (msg.replace(/\n/g, "\n" + prefix)));
    return "" + title + ": " + msg;
  };

  CoffeeAssets.prototype.watch = function() {
    var a, cb, glob, globs, k, kk, suffix, title, _results;
    a = arguments;
    cb = a[a.length - 1];
    if (a.length === 3) {
      globs = [
        {
          "in": [''],
          out: ''
        }
      ];
      title = a[0], suffix = a[1];
    } else if (a.length === 4) {
      title = a[0], globs = a[1], suffix = a[2];
    }
    _results = [];
    for (k in globs) {
      glob = globs[k];
      if (typeof glob["in"] === 'string') {
        glob["in"] = [glob["in"]];
      }
      _results.push((function() {
        var _results1,
          _this = this;
        _results1 = [];
        for (kk in glob["in"]) {
          _results1.push((function(glob) {
            _this.notify('gaze', "watching " + (glob["in"] + glob.suffix), 'pending', false, false);
            return gaze(path.join(process.cwd(), glob["in"] + glob.suffix), function(err, watcher) {
              if (err) {
                _this.notify('gaze', err, 'failure', true, false);
              }
              return  this.on('changed', function(file) {
                return cb({
                  title: title,
                  infile: path.relative(process.cwd(), file),
                  outfile: path.join(glob.out, path.relative(path.join(process.cwd(), glob["in"]), file)),
                  inpath: glob["in"],
                  outpath: glob.out
                });
              });
            });
          })({
            "in": glob["in"][kk] && path.xplat(glob["in"][kk]),
            out: glob.out && path.xplat(glob.out),
            suffix: glob.suffix || suffix
          }));
        }
        return _results1;
      }).call(this));
    }
    return _results;
  };

  CoffeeAssets.prototype.common_compiler = function(compiler_options) {
    var _this = this;
    return function(o) {
      var a, count;
      o.outfile = o.outfile.replace(/\.coffee$/, '');
      if ((a = async.q[o.title]) && a.beginning_length > 0 && (count = a.beginning_length - a.processed) > 0) {
        _this.notify(o.title, "will compile " + o.outfile + " after " + count + " task(s) complete", 'pending', false, true);
      }
      return async.push(o.title, function(next) {
        var wrote;
        wrote = false;
        o.cb = function() {
          wrote = true;
          return next.apply(null, arguments);
        };
        async.delay(500, function() {
          if (!wrote) {
            return _this.notify(o.title, "still compiling " + o.outfile + "...", 'pending', false, true);
          }
        });
        return _this.precompile(o.infile, _this.compiler(compiler_options), _this.write_manager(o));
      });
    };
  };

  CoffeeAssets.prototype.write_manager = function(o) {
    var _this = this;
    return function(err, compiled_output) {
      o.cb = o.cb || function() {};
      if (err) {
        return o.cb(null, _this.notify(o.title, err, 'failure', true, true));
      }
      return _this.write(o.infile, o.outfile, compiled_output, o.asset_path || _this.o.asset_path, function(err) {
        if (err) {
          return o.cb(null, _this.notify(o.title, "unable to write " + o.outfile + ". " + err, 'failure', true, true));
        }
        _this.notify(o.title, "wrote " + o.outfile, 'success', false, true);
        return o.cb(null);
      });
    };
  };

  CoffeeAssets.prototype.write = function(infile, outfile, compiled_output, manifest_path, cb) {
    var manifest_file;
    manifest_file = path.join(manifest_path, 'manifest.json');
    mkdirp.sync(path.dirname(outfile));
    return fs.writeFile(outfile, compiled_output, 'utf8', function(err) {
      if (err) {
        return cb(err);
      }
      return cb(null);
    });
  };

  CoffeeAssets.prototype.child_process_loop = function(o, title, cmd, args) {
    var child, last_start,
      _this = this;
    last_start = new Date();
    child = child_process.spawn(cmd, args);
    child.stdout.on('data', function(stdout) {
      return _this.notify(title, '' + stdout, 'pending', false, false);
    });
    child.stderr.on('data', function(stderr) {
      return _this.notify(title, '' + stderr, 'failure', true, true);
    });
    child.on('exit', function(code) {
      var uptime;
      uptime = new Date() - last_start;
      _this.notify(title, "exit with code " + (code || 0) + " (uptime: " + (uptime / 1000) + "sec). will restart...", 'pending', false, false);
      if (uptime < 2 * 1000) {
        _this.notify(title, 'waiting 3sec to prevent flapping due to short uptime...', 'pending', false, false);
        return async.delay(3 * 1000, function() {
          return o[title] = _this.child_process_loop(o, title, cmd, args);
        });
      } else {
        return o[title] = _this.child_process_loop(o, title, cmd, args);
      }
    });
    this.notify(title, 'spawned new instance', 'success', false, false);
    return o[title] = child;
  };

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
          _this.manifest[file] = {
            length: 0,
            files: {}
          };
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
          if (!_this.manifest[file].files[a[3]]) {
            _this.manifest[file].files[a[3]] = _this.manifest[file].length++;
          }
          return a[0];
        });
        directives.push(code.substr(lx, code.length - lx));
        return cb(null, directives);
      });
    });
  };

  CoffeeAssets.prototype.precompile = function(file, compile, cb, lvl) {
    var m, s, type,
      _this = this;
    if (lvl == null) {
      lvl = 0;
    }
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
            return flow.serial(function(next) {
              s += _this.escape_literal(file, type, code);
              return next();
            });
          })(out[k]);
        } else {
          if (out[k].directive === 'require') {
            (function(file2) {
              return flow.serial(function(next) {
                _this.precompile(file2, compile, (function(err, compiled) {
                  if (err) {
                    return cb(err);
                  }
                  s += compiled;
                  return next(null);
                }), lvl + 1);
              });
            })(path.resolve(path.dirname(file), out[k].file));
          }
        }
      }
      flow["finally"](function(err) {
        if (err) {
          return cb(err);
        }
        if (lvl === 0) {
          compile(file, type, s, cb);
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
      case '.json.coffee':
        return "\n" + code;
      case '.js':
        return "\n" + code.replace(/\`/g, '\\`') + "\n";
      case '.css.coffee':
      case '.html.coffee':
        return "\n" + code;
      case '.css':
      case '.html':
        return "\nliteral " + (JSON.stringify("\n" + code + "\n")) + "\n";
    }
  };

  CoffeeAssets.prototype.compiler = function(o) {
    var _this = this;
    o = o || {};
    o.render_options = o.render_options || {};
    return function(file, type, code, done) {
      var data, engine, js_fn, m, mustache, _;
      try {
        switch (type) {
          case '.json.coffee':
            _ = function(a, b) {
              var c, k;
              c = {};
              for (k in a) {
                c[k] = a[k];
              }
              for (k in b) {
                c[k] = b[k];
              }
              return c;
            };
            data = eval(CoffeeScript.compile(code, {
              bare: true
            }));
            return done(null, JSON.stringify(data, null, 2));
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
            o.render_options.file = file;
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
      if (typeof done === 'function') {
        done(null);
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
        return templates[key] = mustache;
      }
    }), function() {
      var js_fn;
      js_fn = CoffeeTemplates.compileAll(templates, o.compile_options);
      return cb(null, 'var templates=' + js_fn.toString());
    });
  };

  CoffeeAssets.prototype.digest = function() {};

  CoffeeAssets.prototype.minify = function() {};

  CoffeeAssets.prototype.gzip = function() {};

  CoffeeAssets.prototype.clean = function() {};

  return CoffeeAssets;

})();
