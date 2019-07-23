const fs = require('fs');
const gulp = require('gulp');
const {exec} = require('child_process');
const express = require('express');
const checkPages = require('check-pages');
const globber = require('glob');
const cheerio = require('cheerio');

function displayErrors(err, stdout, stderr) {
  if (err) {
    console.log('\nERROR FOUND\n\n' + err);
    console.log('\nDUMPING STDOUT\n\n' + stdout);
    console.log('\nDUMPING STDERR\n\n' + stderr);
    process.exit(1);
  }
}

function checkInternalLinksAndExit(htmlPath) {
  const badLinks = [];

  const $ = cheerio.load(fs.readFileSync(htmlPath, 'utf8'));
  $('a').each((index, anchor) => {
    const href = $(anchor).attr('href') || '';
    if (href.startsWith('#') && href.length > 1) {
      const targetElementById = $(href);
      if (!targetElementById.length) {
        const targetElementByName = $(`[name=${href.substr(1)}]`);
        if (!targetElementByName.length) {
          const text = $(anchor).text();
          badLinks.push({text, href});
        }
      }
    }
  });

  if (badLinks.length) {
    console.log('Found invalid internal links!');
    console.log('Make sure these `href`s correspond to the `id`s of real headings in the HTML:');
    console.log(badLinks.map(({text, href}) => `  - [${text}](${href})`).join('\n'));
    process.exit(1);
  }
}

gulp.task('build', cb => {
  exec('bundle exec middleman build', (err, stdout, stderr) => {
    if (err) {
      return displayErrors(err, stdout, stderr);
    }
    cb();
  });
});

gulp.task('webserver', cb => {
  exec('bundle exec middleman server -p 8000', (err, stdout, stderr) => {
    if (err) {
      return displayErrors(err, stdout, stderr);
    }
    cb();
  });
  console.log('Your docs are waiting for you at http://localhost:8000')
});

gulp.task('default', gulp.series('webserver'));

const checkPagesOptions = {
  checkLinks: true,
  summary: true,
  terse: true
};

const checkPathAndExit = (path, options, done) => {
  const app = express();
  app.use(express.static(path));
  const server = app.listen({port: 8001});

  return checkPages(console, options, (err, stdout, stderr) => {
    server.close();
    done();

    if (err) {
      return displayErrors(err, stdout, stderr);
    }

    return true;
  });
};

gulp.task('checkV3docs', gulp.series('build', done => {
  checkInternalLinksAndExit(`build/index.html`);

  checkPagesOptions.pageUrls = [
    'http://localhost:8001/'
  ];

  checkPagesOptions.linksToIgnore = ['http://localhost:8001/version/release-candidate'];
  checkPathAndExit('build', checkPagesOptions, done);
}));

gulp.task('checkV2docs', done => {
  globber.glob('../v2/**/*.html', (err, htmlFiles) => {
    if (err) {
      return displayErrors(err, 'npm glob failed', '');
    }

    const fixedFiles = htmlFiles.map(fname => {
      return 'http://localhost:8001' + fname.substr('../v2'.length);
    });

    checkPagesOptions.pageUrls = ['http://localhost:8001/'].concat(fixedFiles);

    checkPathAndExit('../v2', checkPagesOptions, done);
  });
});

gulp.task('checkdocs', gulp.parallel('checkV2docs', 'checkV3docs'));
