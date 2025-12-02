# Azure::Core

[![Build Status](https://travis-ci.org/Azure/azure-ruby-asm-core.png?branch=master)](https://travis-ci.org/Azure/azure-ruby-asm-core) 

This project provides a Ruby package with core functionality consumed by Azure SDK gems.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'azure-core'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install azure-core

### Notice
For ruby version >= 1.9.3 && < 2.2.0, please install compatible Nokogiri(version >= 1.6.8), otherwise the installation using old version of bundler or all version of rubygems will report failure.

## Usage
```ruby
 require 'azure/core'
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake test` to run the tests.

## Provide Feedback

If you encounter any bugs with the library please file an issue.

# Code of Conduct 
This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.