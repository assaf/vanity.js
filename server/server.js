#!/usr/bin/env node
var FS    = require("fs"),
    Path  = require("path"),
    HTTP  = require("http"),
    Up    = require("up"),
    OS    = require("os"),
    port, workers, timeout, watch, pid;


// Default environment is development, saves us from accidentally connecting to
// production database.
process.env.NODE_ENV = process.env.NODE_ENV || "development";

// Configuration for production and development.
if (process.env.NODE_ENV == "production") {
  port = 80;
  workers = OS.cpus().length;
  timeout = 60000;
  pid = __dirname + "/tmp/server.pid";
} else {
  port = 3000;
  workers = 1;
  timeout = 1000;
  watch = true;
}


// Fire up the workers.
var httpServer = HTTP.Server().listen(port),
    server = Up(httpServer, __dirname + "/config/worker.js", { numWorkers: workers, workerTimeout: timeout });

if (pid) {
  FS.writeFileSync(pid, process.pid.toString());
}

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
