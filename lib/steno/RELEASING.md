# Releasing Steno

This document describes how to release a new version of the Steno gem.

## Automatic Release Process (Recommended)

Releases are automated via GitHub Actions. Create a release on GitHub, and the gem will be automatically tested, built, and published to RubyGems.

### Steps:

1. **Update version and changelog locally**:
   - Update `lib/steno/version.rb` with the new version number
   - Add an entry to `CHANGELOG.md` describing the changes

2. **Commit and push to main branch**:
   ```bash
   git add lib/steno/version.rb CHANGELOG.md
   git commit -m "Bump version to X.Y.Z"
   git push origin master
   ```

3. **Create a GitHub Release**:
   - Go to https://github.com/cloudfoundry/steno/releases/new
   - Click "Choose a tag" and create a new tag: `vX.Y.Z`
   - Set the release title (e.g., "Release vX.Y.Z")
   - Add a description with the changes from `CHANGELOG.md`
   - Click "Publish release"
   
4. **Workflow runs automatically**:
   - Tests run ✓
   - Gem is built ✓
   - Gem file is attached to the release ✓
   - Gem is published to RubyGems ✓

## Manual Release Process

If you need to release manually without GitHub Actions:

1. **Update version**:
   ```bash
   vim lib/steno/version.rb
   ```

2. **Run tests** to ensure everything works:
   ```bash
   bundle exec rake spec
   ```

3. **Build the gem**:
   ```bash
   gem build steno.gemspec
   ```

4. **Publish to RubyGems** (requires authentication):
   ```bash
   gem push steno-<VERSION>.gem
   ```

5. **Create a git tag and push to GitHub**:
   ```bash
   git tag vX.Y.Z
   git push origin master
   git push --tags
   ```

6. **Create a GitHub Release** (manual):
   - Go to https://github.com/cloudfoundry/steno/releases/new
   - Select the tag you just created
   - Add release notes
   - Attach the `.gem` file if desired
   - Click "Publish release"

## Requirements

- Push access to the GitHub repository
- RubyGems account with publishing rights (for manual releases only)
- For automatic publishing: `RUBYGEMS_API_KEY` secret configured in GitHub Settings

## Version Numbering

Steno follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes to the API
- **MINOR**: New features that are backward-compatible
- **PATCH**: Bug fixes and other minor improvements

Example: `v1.2.3` where 1 is MAJOR, 2 is MINOR, 3 is PATCH

## Checklist Before Release

- [ ] All tests pass locally: `bundle exec rake spec`
- [ ] RuboCop passes: `bundle exec rubocop` (or review any violations)
- [ ] Dependencies are up to date: `bundle update`
- [ ] Version is bumped in `lib/steno/version.rb`
- [ ] Changelog is updated in `CHANGELOG.md`
- [ ] Git history is clean
- [ ] Tests pass in GitHub CI