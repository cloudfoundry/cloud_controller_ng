import { exec } from 'child_process';
import { readFileSync } from 'fs';
import gulp from 'gulp';
import express from 'express';
import { glob } from 'glob';
import { LinkChecker } from 'linkinator';

const cheerio = await import('cheerio');

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
  const $ = cheerio.load(readFileSync(htmlPath, 'utf8'));

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
  const $ = cheerio.load(readFileSync(htmlPath, 'utf8'));
  const syntaxErrors = $('code .err');

  if (syntaxErrors.length) {
    syntaxErrors.each((_index, errorElement) => {
      console.error('⚠️ v3 docs error: Found syntax error');
      console.error('👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇👇')
      console.error($(errorElement.parentNode).text());
      console.error('👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆👆\n')
    });

    process.exit(1);
  }
}

async function checkPathAndExit(path, options, done) {
  const app = express();
  app.use(express.static(path));
  const server = app.listen({ port: 8001 });

  const url = 'http://localhost:8001/';

  const config = {
    path: url,
    linksToSkip: options.linksToSkip || [],
    recurse: options.recurse,
    silent: options.silent,
    markdown: options.markdown,
  };

  try {
    const checker = new LinkChecker();

    if (path === '../v2') {
      const htmlFiles = await glob(path + '/**/*.html');
      let allResults = { links: [] };
      for (let file of htmlFiles) {
        const fileUrl = url + file.substr(path.length);
        const fileConfig = { ...config, path: fileUrl };
        const results = await checker.check(fileConfig);
        allResults.links = allResults.links.concat(results.links);
      }
      displayResults(allResults);
    } else {
      const results = await checker.check(config);
      displayResults(results);
    }

    server.close();
    done();

  } catch (err) {
    server.close();
    done(err);
    process.exit(1);
  }
}

function displayResults(results) {
  const totalLinks = results.links.length;
  const brokenLinks = results.links.filter(link => link.state === 'BROKEN');

  console.log(`Total Links Checked: ${totalLinks}`);
  console.log(`Broken Links Found: ${brokenLinks.length}`);
  if (brokenLinks.length > 0) {
    console.log('Broken Links:');
    brokenLinks.forEach(link => {
      console.log(`  - ${link.url} (status: ${link.status})`);
    });
    process.exitCode = 1;
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

  try {
    checkPathAndExit('build', {
      linksToSkip: ['http://localhost:8001/version/release-candidate'],
      recurse: true,
      silent: true,
      markdown: true,
    }, done);
  } catch (err) {
    done(err);
  }
}));

gulp.task('checkV2docs', done => {
  try {
    checkPathAndExit('../v2', {
      linksToSkip: [],
      recurse: true,
      silent: true,
      markdown: true,
    }, done);
  } catch (err) {
    done(err);
  }
});

gulp.task('checkdocs', gulp.series('checkV2docs', 'checkV3docs'));