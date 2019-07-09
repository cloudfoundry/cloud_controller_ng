require 'spec_helper'

module VCAP::Services
  module ServiceBrokers
    module V2
      module Errors
        RSpec.describe MaintenanceInfoConflict do
          let(:uri) { 'http://www.example.com/' }
          let(:response) { double(code: 422, body: response_body) }
          let(:method) { 'PATCH' }
          let(:response_body) do
            {
              'description' => 'Version mismatch from broker'
            }.to_json
          end
          let(:expected_default_description) do
            'The service broker did not provide a reason for this conflict, ' \
              'please ensure the catalog is up to date and you are providing a version supported by this service plan'
          end

          subject { MaintenanceInfoConflict.new(uri, method, response) }

          it 'puts the correct description in the error' do
            expect(subject.to_h['description']).to eq('Service broker error: Version mismatch from broker')
          end

          it 'renders the correct status code to the user' do
            expect(subject.response_code).to eq 422
          end

          [
            { 'description' => '' }.to_json,   # description is empty string
            { 'description' => ' ' }.to_json,  # description contains only whitespace
            { 'description' => "\n" }.to_json, # description contains only newline char
            { 'description' => nil }.to_json,  # description is null
            { 'description' => true }.to_json, # description is not a String
            { 'foo' => 'bar' }.to_json,        # description is not a key in the body
            'string',                          # body is not a hash
          ].each do |fake_body|
            context "when the body is '#{fake_body}'" do
              let(:response_body) { fake_body }

              it 'generates a description and puts it in the error' do
                expect(subject.to_h['description']).to eq(expected_default_description)
              end
            end
          end
        end
      end
    end
  end
end
