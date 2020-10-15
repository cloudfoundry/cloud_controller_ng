Cloud Foundry API Docs
======================

Built with [Slate](https://github.com/lord/slate).

Getting Started
---------------

- Ensure you have Ruby 2.4.x installed
- Ensure you have Bundler installed and have run `bundle install` in this directory
- Ensure you have the latest version of NodeJS installed
- Get the npm dependencies: `npm install`
- Start the test server: `npm start`
- You can now see the docs at <http://localhost:8000>.

Making New Files
----------------

When you create a new file, ensure you include it in `source/index.md`.

JSON examples exist under `source/include/api_resources`, these need to be added to the top of `source/index.md`.

Style Rules
-----------
- Ordering of sections:
  - header
  - object
  - extra object info
  - create
  - get/read
  - list
  - update
  - delete
  - alphabetical everything else
- Object names should be lowercased and separated by a space
- Every object description should have examples
- Every request should have a "Permitted Roles"
  - Use "All Roles" to define any set of permissions that do not apply to org/space managers, developers, etc.
- Optional params should be omitted from request examples.


To Push the docs as a cf app:
---

From this directory:
```bash
bundle exec middleman build
cf push docs -b staticfile_buildpack -p ./build
```