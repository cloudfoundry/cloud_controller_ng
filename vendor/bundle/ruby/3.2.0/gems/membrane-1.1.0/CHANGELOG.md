# Membrane changelog

## 1.0.0

* Bump version to 1.0.0 to reflect changes from 0.0.x versions and to denote general stability of gem.


## 0.0.5

* Refactor `fail!` methods in Schema types.


## 0.0.4

* Rename `Membrane::Schema` to `Membrane::Schemas`. This is backwards-incompatible for any code relying directly on this module.
* Make schemas extensible.
* Update licenses.


## 0.0.3

* Fix indentation.


## 0.0.2

* Add deparse method for schema classes:
    - The method: Membrane::Schema::Base#deparse returns string representation of a schema.
    - Changed class: Membrane::Schema::Dictionary to sub-class Membrane::Schema::Base.
    - Changed method: Membrane::SchemaParser#deparse to call `name` instead of `inspect` on a `Membrane::Schema::Class` object.
    - Added/changed tests.
* Add tuple schema.
* Better pretty printing for schemas.


## 0.0.1

* Initial commit.
