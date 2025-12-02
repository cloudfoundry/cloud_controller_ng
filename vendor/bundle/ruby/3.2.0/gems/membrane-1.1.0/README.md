[![Build Status](https://travis-ci.org/cloudfoundry/membrane.png)](https://travis-ci.org/cloudfoundry/membrane)

# Membrane

Membrane provides an easy to use DSL for specifying validators declaratively.
It's intended to be used to validate data received from external sources,
such as API endpoints or config files. Use it at the edges of your process to
decide what data to let in and what to keep out.

## Overview

The core concept behind Membrane is the ```schema```. A ```schema``` represents
an invariant about a piece of data (similar to a type) and is capable of
verifying whether or not a supplied datum satisfies the invariant. Schemas may
be composed to produce more expressive constructs.

Membrane provides a handful of useful schemas out of the box. You should be
able to construct the majority of your schemas using only what is provided
by default.


*Any*

The ```Any``` schema accepts all values; use it sparingly. It is synonymous to
the Object class in Ruby.

*Bool*

The ```Bool``` schema accepts only the values ```true``` and ```false```.

*Class*

The ```Class``` schema is parameterized by an instance of
```Class```. It accepts any values that are instances of the supplied class.
This is verified using ```kind_of?```.

*Dictionary*

The ```Dictionary``` schema is parameterized by a key schema and a
value schema.  It accepts hashes whose keys and values validate against their
respective schemas.

*Enum*

The ```Enum``` parameterized by an arbitrary number of value schemas. It
accepts any values that are accepted by at least one of the supplied schemas.

*List*

The ```List``` schema is parameterized by a single element schema. It accepts
arrays whose elements are accepted by the supplied schema.

*Record*

The ```Record``` schema is parameterized by a set of known keys and their
respective schemas. It accepts hashes that contain all the supplied keys,
assuming the corresponding values are accepted by their respective schemas.

*Regexp*

The ```Regexp``` schema is parameterized by a regular expression. It accepts
strings that match the supplied regular expression.

*Tuple*

The ```Tuple``` schema is parameterized by a fixed number of schemas. It accepts
arrays of the same length, where each element is accepted by its associated
schema.

*Value*

The ```Value``` schema is parameterized by a single value. It accepts values
who are equal to the parameterizing value using ```==```.

## DSL

Membrane schemas are typically created using a concise DSL. The aforementioned
schemas are represented in the DSL as follows:

*Any*

The ```Any``` schema is represented by the keyword ```any```.

*Bool*

The ```Bool``` schema is represented by the keyword ```bool```.

*Class*

The ```Class``` schema is represented by the parameterizing instance of ```Class```.
For example, an instance of the Class schema that validates strings would be
represented as ```String```.

*Dictionary*

The ```Dictionary``` schema is represented by ```dict(key_schema,
value_schema```, where ```key_schema``` is the schema used to validate keys,
and ```value_schema``` is the schema used to validate values.

*Enum*

The ```Enum``` schema is represented by ```enum(schema1, ..., schemaN)```
where ```schema1``` through ```schemaN``` are the possible value schemas.

*List*

The ```List``` schema is represented by ```[elem_schema]```, where
```elem_schema``` is the schema that all list elements must validate against.

*Record*

The ```Record``` schema is represented as follows:

    { "key1"           => value1_schema,
      optional("key2") => value2_schema,
      ...
    }

Here ```key1``` must be contained in the hash and the corresponding value must
be accepted by ```value1_schema```. Note that ```key2``` is marked as optional.
If present, its corresponding value must be accepted by ```value2_schema```.

*Regexp*

The ```Regexp``` schema is represented by regexp literals. For example,
```/foo|bar/``` matches strings containing "foo" or "bar".

*Tuple*

The ```Tuple``` schema is represented as ```tuple(schema0, ..., schemaN)```,
where the Ith element of an array must be accepted by ```schemaI```.

*Value*

The ```Value``` schema is represented by the value to be validated. For example,
```"foo"``` accepts only the string "foo".

## Usage

While the previous section was a bit abstract, the DSL is fairly intuitive.
For example, the following creates a schema that will validate a hash where the
key "ints" maps to a list of integers and the key "string" maps to a string.

    schema = Membrane::SchemaParser.parse do
      { "ints"   => [Integer],
        "string" => String,
      }
    end

    # Validates successfully
    schema.validate({
      "ints"   => [1],
      "string" => "hi",
    })

    # Fails validation. The key "string" is missing and the value for "ints"
    # isn't the correct type.
    schema.validate({
      "ints" => "invalid",
    })

This is a more complicated example that illustrate the entire DSL. Hopefully
it is self-explanatory:

    Membrane::SchemaParser.parse do
      { "ints"          => [Integer]
        "true_or_false" => bool,
        "anything"      => any, # You can also use Object instead.
        optional("_")   => any,
        "one_or_two"    => enum(1, 2),
        "strs_to_ints"  => dict(String, Integer),
        "foo_prefix"    => /^foo/,
        "three_ints"    => tuple(Integer, Integer, Integer),
      }
    end

## Adding new schemas

Adding a new schema is trivial. Any class implementing the following "interface"
can be used as a schema:

    # @param [Object] The object being validated.
    #
    # @raise [Membrane::SchemaValidationError] Raised when a supplied object is
    # invalid.
    #
    # @return [nil]
    def validate(object)

If you wish to include your new schema as part of the DSL, you'll need to
modify ```membrane/schema_parser.rb``` and have your class inherit from ```Membrane::Schemas::Base```
