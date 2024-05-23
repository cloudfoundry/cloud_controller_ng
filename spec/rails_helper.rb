require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
Rails.env = 'test'
require 'rspec/rails'

def parsed_body
  Oj.load(response.body)
end
