// Generated by CoffeeScript 1.4.0
var CoffeeAssets, CoffeeScript, CoffeeSprites, CoffeeStylesheets, CoffeeTemplates, async, child_process, fs, gaze, growl, mkdirp, path, require_fresh,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

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

  function CoffeeAssets() {
    this.write_manager = __bind(this.write_manager, this);
    this.sandboxes = {};
    this.manifest = {};
    this._titles = {};
    this._color_index = 0;
    this.colors = ['\u001b[33m', '\u001b[34m', '\u001b[35m', '\u001b[36m', '\u001b[31m', '\u001b[32m', '\u001b[1m\u001b[33m', '\u001b[1m\u001b[34m', '\u001b[1m\u001b[35m', '\u001b[1m\u001b[36m', '\u001b[1m\u001b[31m', '\u001b[1m\u001b[32m'];
    this.node_child = null;
  }

  CoffeeAssets.path = path;

  CoffeeAssets.require_fresh = require_fresh;

  CoffeeAssets.prototype.notify = function(title, msg, image, err, show) {
    if (typeof this._titles[title] === 'undefined') {
      this._titles[title] = this._color_index++;
    }
    if (err && typeof msg === 'object' && typeof msg.stack !== 'undefined') {
      msg = msg.stack;
    }
    console.log("" + this.colors[this._titles[title]] + title + ":\u001b[0m " + (msg.toString().replace(/[\r\n]+$/, '')));
    if (show) {
      return growl(msg, {
        image: path.xplat(__dirname, "/../images/" + image + ".png"),
        title: title
      });
    }
  };

  CoffeeAssets.prototype.watch = function() {
    var a, cb, glob, globs, k, kk, suffix, _results;
    a = arguments;
    cb = a[a.length - 1];
    if (a.length === 2) {
      globs = [
        {
          "in": [''],
          out: ''
        }
      ];
      suffix = a[0];
    } else if (a.length === 3) {
      globs = a[0];
      suffix = a[1];
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
                var relout;
                relout = path.join(glob.out, path.relative(path.join(process.cwd(), glob["in"]), file));
                return cb(path.relative(process.cwd(), file), relout, glob["in"], glob.out);
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

  CoffeeAssets.prototype.write_manager = function(asset_path, title, infile, outfile) {
    var _this = this;
    return function(err, compiled_output) {
      if (err) {
        return _this.notify(title, err, 'failure', true, true);
      }
      return _this.write(infile, outfile, compiled_output, asset_path, function(err) {
        if (err) {
          return _this.notify(title, "unable to write " + outfile + ". " + err, 'failure', true, true);
        }
        return _this.notify(title, "wrote " + outfile, 'success', false, true);
      });
    };
  };

  CoffeeAssets.prototype.restart_node = function() {
    if (this.node_child) {
      return this.node_child.kill();
    }
  };

  CoffeeAssets.prototype.start_node = function() {
    var last_start,
      _this = this;
    last_start = new Date();
    this.node_child = child_process.spawn('node', ['server.js']);
    this.node_child.stdout.on('data', function(stdout) {
      return _this.notify('node', '' + stdout, 'pending', false, false);
    });
    this.node_child.stderr.on('data', function(stderr) {
      return _this.notify('node', '' + stderr, 'failure', true, false);
    });
    this.node_child.on('exit', function(code) {
      var uptime;
      uptime = new Date() - last_start;
      _this.notify('node', "node server died (uptime: " + (uptime / 1000) + "sec)", 'pending', false, false);
      if (uptime < 2 * 1000) {
        _this.notify('node', 'due to short uptime, 15sec to restart...', 'pending', false, false);
        return setTimeout(start_node, 15 * 1000);
      } else {
        return start_node();
      }
    });
    return this.notify('node', 'spawned new server instance', 'pending', false, false);
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

  CoffeeAssets.prototype.write = function(infile, outfile, compiled_output, manifest_path, cb) {
    var manifest_file, write_outfile;
    manifest_file = path.join(manifest_path, 'manifest.json');
    write_outfile = function() {
      mkdirp.sync(path.dirname(outfile));
      return fs.writeFile(outfile, compiled_output, 'utf8', function(err) {
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
