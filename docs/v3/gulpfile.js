const fs = require('fs');
const gulp = require('gulp');
const { exec } = require('child_process');
const express = require('express');
const { glob } = require('glob');
const cheerio = require('cheerio');

async function linkCheck(options) {
  const { LinkChecker } = await import('linkinator');
  const checker = new LinkChecker();

  return await checker.check({
    path: options.pageUrls[0],
    linksToSkip: options.linksToSkip,
    recurse: true,
    concurrency: 5
  });
}

function displayErrors(err, stdout, stderr) {
  if (err) {
    console.log('\nERROR FOUND\n\n' + err);
    console.log('\nDUMPING STDOUT\n\n' + stdout);
    console.log('\nDUMPING STDERR\n\n' + stderr);
    process.exit(1);
  }
}

function checkInternalLinksAndExit(htmlPath) {
  const duplicateHeadingIds = [];
  const seenHeadingIds = new Set();
  const badLinks = [];
  const $ = cheerio.load(fs.readFileSync(htmlPath, 'utf8'));

  $('a').each((index, anchor) => {
    const href = $(anchor).attr('href') || '';

    if (href.startsWith('#') && href.length > 1) {
      const foundElementById = $(href).length > 0;
      if (foundElementById) return;

      const foundElementByName = $(`[name=${href.substr(1)}]`).length > 0;
      if (foundElementByName) return;

      const text = $(anchor).text();
      badLinks.push({ text, href });
    }
  });

  $('h1,h2,h3').each((index, element) => {
    const id = $(element).attr('id');
    if (id) {
      if (seenHeadingIds.has(id)) duplicateHeadingIds.push(id);
      else seenHeadingIds.add(id);
    }
  });

  if (badLinks.length) {
    console.error('v3 docs error: Found invalid internal links');
    console.error('Make sure these `href`s correspond to the `id`s of real headings in the HTML:');
    console.error(badLinks.map(({ text, href }) => `  - [${text}](${href})`).join('\n'));
  }

  if (duplicateHeadingIds.length) {
    console.error('v3 docs error: Found multiple headings with the same `id`');
    console.error('Make sure `id`s are unique so internal links will work as expected.');
    console.error(duplicateHeadingIds.map(id => `  - #${id}`).join('\n'))
  }

  if (badLinks.length || duplicateHeadingIds.length) {
    process.exit(1);
  }
}

function checkSyntaxErrorsAndExit(htmlPath) {
  const $ = cheerio.load(fs.readFileSync(htmlPath, 'utf8'));
  const syntaxErrors = $('code .err');

  if (syntaxErrors.length) {
    syntaxErrors.each((_index, errorElement) => {
      console.error('⚠️ v3 docs error: Found syntax error');
      console.error('👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇')
      console.error($(errorElement.parentNode).text());
      console.error('👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆\n')
    });

    process.exit(1)
  }
}

async function checkPathAndExit(path, options, done) {
  const app = express();
  app.use(express.static(path));
  const server = app.listen({ port: 8001 });
  
  try {
    const result = await linkCheck({
      linksToSkip: options.linksToSkip,
      pageUrls: (options.pageUrls && options.pageUrls.length) ? options.pageUrls : ['http://localhost:8001/']
    });

    server.close();
    done();

    if (result.passed === false) {
      // linkinator gives us a state for each link, e.g. 'BROKEN', 'OK', 'SKIPPED' etc.
      const brokenLinks = result.links.filter(x => x.state === 'BROKEN');
      console.error(`Found ${brokenLinks.length} broken links:`);
      brokenLinks.forEach((link) => {
        console.error(`- ${link.url}: ${link.status}`);
      });
      process.exit(1);
    }
  } catch (err) {
    server.close();
    done();
    displayErrors(err, '', '');
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
  console.log('Your docs are waiting for you at http://localhost:8000');
});

gulp.task('default', gulp.series('webserver'));

gulp.task('checkV3docs', gulp.series('build', done => {
  checkInternalLinksAndExit('build/index.html');
  checkSyntaxErrorsAndExit('build/index.html');

  checkPathAndExit('build', {
    checkLinks: true,
    summary: true,
    terse: true,
    onlySameDomain: true,
    pageUrls: ['http://localhost:8001/'],
    linksToSkip: ['http://localhost:8001/version/release-candidate']
  }, done);
}));

gulp.task('checkV2docs', async (done) => {
  const htmlFiles = await new Promise((resolve, reject) => {
    glob('../v2/**/*.html', (err, matches) => {
      if (err) return reject(err);
      resolve(matches);
    });
  });

  const fixedFiles = htmlFiles.map(fname => {
    return 'http://localhost:8001' + fname.substr('../v2'.length);
  });

  checkPathAndExit('../v2', {
    checkLinks: true,
    summary: true,
    terse: true,
    onlySameDomain: true,
    pageUrls: ['http://localhost:8001/'].concat(fixedFiles),
    linksToSkip: []
  }, done);
});

gulp.task('checkdocs', gulp.parallel('checkV2docs', 'checkV3docs'));