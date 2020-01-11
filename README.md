# jddf-ruby [![][packagist-badge]][packagist-url] [![][ci-badge]][ci-url]

> Documentation on rubydoc.info: https://www.rubydoc.info/github/jddf/jddf-ruby

This gem is a Ruby implementation of **JSON Data Definition Format**, a schema
language for JSON. You can use this gem to:

1. Validate input data against a schema,
2. Get a list of validation errors from that input data, or
3. Build your own tooling on top of JSON Data Definition Format

[packagist-badge]: https://img.shields.io/packagist/v/jddf/jddf
[ci-badge]: https://github.com/jddf/jddf-php/workflows/PHP%20CI/badge.svg?branch=master
[packagist-url]: https://packagist.org/packages/jddf/jddf
[ci-url]: https://github.com/jddf/jddf-php/actions

## Installing

You can install this gem by running:

```bash
gem install jddf
```

Or if you're using Bundler:

```ruby
gem 'jddf'
```

## Usage

The two most important classes offered by the `JDDF` module are:

- [`Schema`][schema], which represents a JDDF schema,
- [`Validator`][validator], which can validate a `Schema` against any parsed
  JSON data, and
- [`ValidationError`][validation-error], which represents a single validation
  problem with the input. `Validator#validate` returns an array of these.

[schema]: https://www.rubydoc.info/github/jddf/jddf-ruby/master/JDDF/Schema
[validator]: https://www.rubydoc.info/github/jddf/jddf-ruby/master/JDDF/Validator
[validation-error]: https://www.rubydoc.info/github/jddf/jddf-ruby/master/JDDF/ValidationError

Here's a working example:

```ruby
require 'jddf'

# In this example, we're passing in a Hash directly into Schema#from_json, but
# this type of Hash is exactly what JSON#parse returns.
schema = JDDF::Schema.from_json({
  'properties' => {
    'name' => { 'type' => 'string' },
    'age' => { 'type' => 'uint32' },
    'phones' => {
      'elements' => { 'type' => 'string' }
    }
  }
})

# Like before, in order to keep things simple we're construct raw Ruby values
# here. But you can also get this sort of data by parsing JSON using the
# standard library's JSON#parse.
#
# This input data is perfect. It satisfies all the schema requirements.
input_ok = {
  'name' => 'John Doe',
  'age' => 43,
  'phones' => [
    '+44 1234567',
    '+44 2345678'
  ]
}

# This input data has problems. "name" is missing, "age" has the wrong type,
# and "phones[1]" has the wrong type.
input_bad = {
  'age' => '43',
  'phones' => [
    '+44 1234567',
    442345678
  ]
}

# Validator can validate schemas against inputs. Validator#validate returns an
# array of ValidationError.
#
# These ValidationError instances are portable -- every implementation of JDDF,
# across every language, returns the same errors.
validator = JDDF::Validator.new
result_ok = validator.validate(schema, input_ok)
result_bad = validator.validate(schema, input_bad)

p result_ok.size  # 0
p result_bad.size # 3

# This error indicates that "name" is missing.
#
# #<struct JDDF::ValidationError instance_path=[], schema_path=["properties", "name"]
p result_bad[0]

# This error indicates that "age" has the wrong type.
#
# #<struct JDDF::ValidationError instance_path=["age"], schema_path=["properties", "age", "type"]>
p result_bad[1]

# This error indicates that "phones[1]" has the wrong type.
#
# #<struct JDDF::ValidationError instance_path=["phones", "1"], schema_path=["properties", "phones", "elements", "type"]>
p result_bad[2]
```
