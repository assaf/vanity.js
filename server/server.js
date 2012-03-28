#!/usr/bin/env node
var FS     = require("fs"),
    Path   = require("path"),
    HTTP   = require("http"),
    Up     = require("up"),
    OS     = require("os"),
    workers, watch, port, pid;


// Default environment is development, saves us from accidentally connecting to
// production database.
process.env.NODE_ENV = process.env.NODE_ENV || "development";

// Configuration for production and development.
if (process.env.NODE_ENV == "production") {
  workers = OS.cpus().length;
  pid = Path.resolve(__dirname, "tmp/pids/server.pid");
  port = 80;
  timeout = 60000;
} else {
  workers = 1;
  watch = true;
  port = 3000;
  timeout = 1000;
}
port = parseInt(process.env.PORT || port, 10);
timeout = parseInt(process.env.TIMEOUT || timeout, 10);


// Fire up the workers.
var httpServer = HTTP.Server().listen(port),
    server = Up(httpServer, Path.resolve(__dirname, "config/worker.js"), { numWorkers: workers, workerTimeout: timeout });

if (pid)
  FS.writeFileSync(pid, process.pid.toString());

process.on("SIGUSR2", function () {
  console.log("Restarting ...");
  server.reload();
});


// In development, watch files for changes and restart.
if (watch) {
  console.log("Watching for changes ...");
  var ignore = ['node_modules', '.git'];
  function ignored (path) {
    return !~ignore.indexOf(path);
  };
  function files (dir, ret) {
    ret = ret || [];
    FS.readdirSync(dir).filter(ignored).forEach(function(p){
      p = Path.join(dir, p);
      if (FS.statSync(p).isDirectory()) {
        files(p, ret);
      } else if (p.match(/\.js$|\.coffee$/)) {
        ret.push(p);
      }
    });
    return ret;
  };
  function watchFiles(files, fn){
    var options = { interval: 100 };
    files.forEach(function (file) {
      FS.watchFile(file, options, function (curr, prev) {
        if (prev.mtime < curr.mtime) fn(file);
      });
    });
  };
  watchFiles(files(process.cwd()), function (file) {
    console.log("Reloading ...")
    server.reload();
  });
}
