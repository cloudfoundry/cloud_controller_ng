# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'config/default.yml', type: :feature do
  subject(:config) { RuboCop::ConfigLoader.load_file('config/default.yml') }

  let(:configuration_keys) { config.tap { |c| c.delete('inherit_mode') }.keys }
  let(:version_regexp) { /\A\d+\.\d+(?:\.\d+)?\z|\A<<next>>\z/ }

  shared_examples 'has a nicely formatted description' do |cop_name|
    it 'does not contain new lines' do
      description = config.dig(cop_name, 'Description')

      expect(description.include?("\n")).to be(false)
    end

    it 'stars from a verb' do # rubocop:disable RSpec/ExampleLength
      description = config.dig(cop_name, 'Description')
      start_with_subject = description.match(/\AThis cop (?<verb>.+?) .*/)
      suggestion = start_with_subject[:verb]&.capitalize if start_with_subject
      suggestion ||= 'a verb'

      expect(start_with_subject).to(
        be_nil, "should be started with `#{suggestion}` instead of `This cop ...`."
      )
    end

    it 'has a period at EOL of description' do
      description = config.dig(cop_name, 'Description')

      expect(description).to match(/\.\z/)
    end
  end

  shared_examples 'has metadata' do |cop_name|
    context 'with VersionAdded' do
      it 'required' do
        version = config.dig(cop_name, 'VersionAdded')
        expect(version).not_to be_nil
      end

      it 'nicely formatted' do
        version = config.dig(cop_name, 'VersionAdded')
        expect(version).to match(version_regexp), "should be format ('X.Y' or 'X.Y.Z' or '<<next>>')"
      end
    end

    context 'with VersionChanged' do
      it 'nicely formatted' do
        version = config.dig(cop_name, 'VersionChanged')
        next unless version

        expect(version).to match(version_regexp), "should be format ('X.Y' or 'X.Y.Z' or '<<next>>')"
      end
    end

    context 'with VersionRemoved' do
      it 'nicely formatted' do
        version = config.dig(cop_name, 'VersionRemoved')
        next unless version

        expect(version).to match(version_regexp), "should be format ('X.Y' or 'X.Y.Z' or '<<next>>')"
      end
    end

    context 'with Safe' do
      it 'does not include `true`' do
        safe = config.dig(cop_name, 'Safe')
        expect(safe).not_to be(true), 'has unnecessary `Safe: true` config.'
      end
    end

    context 'with SafeAutoCorrect' do
      it 'does not include unnecessary `false`' do
        next unless config.dig(cop_name, 'Safe') == false

        safe_autocorrect = config.dig(cop_name, 'SafeAutoCorrect')

        expect(safe_autocorrect).not_to be(false), 'has unnecessary `SafeAutoCorrect: false` config.'
      end
    end
  end

  cop_names = RuboCop::Cop::Registry.global.with_department(:Sequel).cops.map(&:cop_name)
  cop_names.each do |cop_name|
    describe "Cop #{cop_name}" do
      include_examples 'has a nicely formatted description', cop_name
      include_examples 'has metadata', cop_name
    end
  end

  it 'sorts configuration keys alphabetically' do
    expected = configuration_keys.sort
    configuration_keys.each_with_index do |key, idx|
      expect(key).to eq expected[idx]
    end
  end

  it 'sorts cop names alphabetically' do # rubocop:disable RSpec/ExampleLength
    previous_key = ''
    config_default = YAML.load_file('config/default.yml')

    config_default.each_key do |key|
      next if %w[inherit_mode AllCops].include?(key)

      expect(previous_key <= key).to be(true), "Cops should be sorted alphabetically. Please sort #{key}."
      previous_key = key
    end
  end
end
