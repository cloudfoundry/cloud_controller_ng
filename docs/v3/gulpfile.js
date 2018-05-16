var gulp = require('gulp');
var exec = require('child_process').exec;
var webserver = require('gulp-webserver');
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

gulp.task('middleman', function(cb) {
  exec('bundle exec middleman build', function(err, stdout, stderr) {
    if (err) {
      return displayErrors(err, stdout, stderr);
    }
    cb();
  });
});

gulp.task('webserver', ['middleman'], function() {
  gulp.src('build').pipe(webserver({
    livereload: true
  }));
});

gulp.task('watch', function() {
  gulp.watch(['source/**/*'], ['middleman']);
});

gulp.task('default', ['middleman', 'webserver', 'watch']);


var checkPagesOptions = {
  checkLinks: true,
  summary: true,
  terse: true
};

var checkPathAndExit = function(path, options) {
  var stream = gulp.src(path).pipe(webserver({
    livereload: false
  }));

  return checkPages(console, options, function(err, stdout, stderr) {
    stream.emit("kill");

    if (err != undefined) {
      return displayErrors(err, stdout, stderr);
    } else {
      return true;
    }
  });
};

gulp.task("checkV3docs", ["middleman"], function(cb) {
  checkPagesOptions.pageUrls = [
    'http://localhost:8000/'
  ];

  checkPagesOptions.linksToIgnore = ["http://localhost:8000/version/release-candidate"];

  checkPathAndExit("build", checkPagesOptions);

});

gulp.task("checkV2docs", [], function(cb) {
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
    checkPathAndExit("../v2", checkPagesOptions);

    cb();
    return;
  });
});

gulp.task("checkdocs", ["checkV2docs", "checkV3docs"], function(cb) {});
