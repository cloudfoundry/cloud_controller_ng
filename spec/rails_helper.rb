require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
Rails.env = 'test'
require 'rspec/rails'

def parsed_body
  JSON.parse(response.body)
end
