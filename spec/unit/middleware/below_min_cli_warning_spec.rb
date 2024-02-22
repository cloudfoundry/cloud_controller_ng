require 'spec_helper'
require 'below_min_cli_warning'

module CloudFoundry
  module Middleware
    RSpec.describe BelowMinCliWarning do
      subject { described_class.new(app) }
      let(:app) { double(:app, call: [200, {}, 'a body']) }
      let(:env) { { 'HTTP_USER_AGENT' => 'mocked-user-agent', 'REQUEST_PATH' => '/v3/organizations' } }

      before { TestConfig.override(info: { min_cli_version: '7.0.0' }, warn_if_below_min_cli_version: true) }

      describe 'below min cli version middleware is called' do
        context 'called with outdated cf cli version' do
          before { allow(subject).to receive(:is_below_min_cli_version?).and_return(true) }

          it 'sets X-Cf-Warnings header' do
            _, headers = subject.call(env)
            expect(headers['X-Cf-Warnings']).to eq(subject.escaped_warning)
          end

          it 'appends to the existing X-Cf-Warnings header' do
            _, headers = subject.call(env.merge!({ 'X-Cf-Warnings' => 'a-warning' }))
            expect(headers['X-Cf-Warnings']).to eq("a-warning%2C#{subject.escaped_warning}")
          end
        end

        context 'called with current cf cli version' do
          before { allow(subject).to receive(:is_below_min_cli_version?).and_return(false) }

          it 'does not add X-Cf-Warnings header' do
            _, headers = subject.call(env)
            expect(headers['X-Cf-Warnings']).to be_nil
          end
        end

        context 'checks the request path' do
          before { allow(subject).to receive(:is_below_min_cli_version?).and_return(true) }

          %w[/v3/processes /v2/services /something/stats].each do |endpoint|
            it "does not set X-Cf-Warnings header for #{endpoint}" do
              _, headers = subject.call(env.merge!({ 'REQUEST_PATH' => endpoint }))
              expect(headers['X-Cf-Warnings']).to be_nil
            end
          end

          %w[/v3/spaces /v2/spaces /v3/organizations /v2/organizations].each do |endpoint|
            it "sets X-Cf-Warnings header for #{endpoint}" do
              _, headers = subject.call(env.merge!({ 'REQUEST_PATH' => endpoint }))
              expect(headers['X-Cf-Warnings']).to eq(subject.escaped_warning)
            end
          end
        end
      end

      describe 'is_below_min_cli_version?' do
        ['some-client',
         'cf7/7.5.0+0ad1d6398.2022-06-04 (go1.17.10; amd64 windows)',
         'cf/7.7.2+b663981.2023-08-31 (go1.20.7; amd64 linux)',
         'cf/8.7.5+8aa8625.2023-11-20 (go1.21.4; arm64 darwin)',
         'cf8.exe/8.3.0+e6f8a853a.2022-03-11 (go1.17.7; amd64 windows)',
         'cf8/8.7.4+db5d612.2023-10-20 (go1.21.3; amd64 linux)',
         'cf.exe/7.4.0+e55633fed.2021-11-15 (go1.16.6; amd64 windows)',
         'Cf/8.5.0+73aa161.2022-09-12 (go1.18.5; arm64 darwin)'].each do |user_agent|
          it("returns false for #{user_agent}") { expect(subject).not_to be_is_below_min_cli_version(user_agent) }
        end

        ['cf/6.46.0+29d6257f1.2019-07-09 (go1.12.7; amd64 windows)',
         'CF/6.46.0+29d6257f1.2019-07-09 (go1.12.7; amd64 windows)',
         'Cf/6.46.0+29d6257f1.2019-07-09 (go1.12.7; amd64 windows)',
         'cf.exe/6.6.0+e25762999.2023-02-16 (go1.19.5; amd64 windows)',
         'cf/6.43.0 (go1.10.8; amd64 linux)',
         'cf6/6.53.0+bommel'].each do |user_agent|
          it("returns true for #{user_agent}") { expect(subject).to be_is_below_min_cli_version(user_agent) }
        end
      end
    end
  end
end
