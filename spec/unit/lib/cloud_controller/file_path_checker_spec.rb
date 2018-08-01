require 'spec_helper'

module VCAP
  module CloudController
    RSpec.describe FilePathChecker do
      subject(:checker) { FilePathChecker }

      context 'File uses a relative path' do
        context 'Path does not escape root' do
          it { should be_safe_path 'subdir/file' }
          it { should be_safe_path 'subdir/../file' }
        end

        context 'Path does escape root' do
          it { should_not be_safe_path '../file' }
          it { should_not be_safe_path 'subdir/../../file' }
        end
      end

      context 'File uses an absolute path' do
        it { should_not be_safe_path '/usr/bin/local' }
      end

      context 'when specifying a root path' do
        context 'File uses an absolute path that includes the root path' do
          it { should be_safe_path '/usr/bin/local/', '/usr/bin' }
        end

        context 'File escapes root but goes back in' do
          it { should be_safe_path '/usr/bin/../bin/local', '/usr/bin' }
        end
      end
    end
  end
end
