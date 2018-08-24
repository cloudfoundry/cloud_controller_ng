var gulp = require('gulp');
var exec = require('child_process').exec;
var express = require('express');
var checkPages = require("check-pages");
var globber = require("glob");


function displayErrors(err, stdout, stderr) {
  if (err != undefined) {
    console.log("\nERROR FOUND\n\n" + err);
    console.log("\nDUMPING STDOUT\n\n" + stdout);
    console.log("\nDUMPING STDERR\n\n" + stderr);
    process.exit("1");
  }
}

gulp.task('build', function(cb) {
  exec('bundle exec middleman build', function(err, stdout, stderr) {
    if (err) {
      return displayErrors(err, stdout, stderr);
    }
    cb();
  });
});

gulp.task('webserver', function(cb) {
  exec('bundle exec middleman server -p 8000', function(err, stdout, stderr) {
    if (err) {
      return displayErrors(err, stdout, stderr);
    }
    cb();
  });
  console.log("Your docs are waiting for you at http://localhost:8000")
});

gulp.task('default', gulp.series('webserver'));

var checkPagesOptions = {
  checkLinks: true,
  summary: true,
  terse: true
};

var checkPathAndExit = function(path, options, done) {
  var app = express();
  app.use(express.static(path));
  var server = app.listen({port: 8000});

  return checkPages(console, options, function(err, stdout, stderr) {
    server.close();
    done();

    if (err != undefined) {
      return displayErrors(err, stdout, stderr);
    } else {
      return true;
    }
  });
};

gulp.task("checkV3docs", gulp.series("build", function(done) {
  checkPagesOptions.pageUrls = [
    'http://localhost:8000/'
  ];

  checkPagesOptions.linksToIgnore = ["http://localhost:8000/version/release-candidate"];

  checkPathAndExit("build", checkPagesOptions, done);

}));

gulp.task("checkV2docs", function(done) {
  globber.glob("../v2/**/*.html", function(err, htmlFiles) {
    if (err) {
      return displayErrors(err, "npm glob failed", "");
    }

    var fixedFiles = htmlFiles.map(function(fname) {
      return "http://localhost:8000" + fname.substr("../v2".length);
    });

    checkPagesOptions.pageUrls = [
      'http://localhost:8000/'
    ].concat(fixedFiles);
    checkPathAndExit("../v2", checkPagesOptions, done);
    return;
  });
});

gulp.task("checkdocs", gulp.parallel("checkV2docs", "checkV3docs"));
