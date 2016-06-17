require 'spec_helper'

module CloudController::Presenters::V2
  RSpec.describe RelationsPresenter do
    describe '#to_hash' do
      let(:test_model) { VCAP::CloudController::TestModel.make(unique_value: 'something', required_attr: true) }
      let(:opts) { {} }

      before do
        test_model.remove_all_test_model_many_to_ones
        test_model.remove_all_test_model_many_to_manies
      end

      it 'includes urls for each related association on the object' do
        hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts, 0, [])
        expect(hash).to eql(
          {
            'test_model_many_to_ones_url' => "/v2/test_models/#{test_model.guid}/test_model_many_to_ones",
            'test_model_many_to_manies_url' => "/v2/test_models/#{test_model.guid}/test_model_many_to_manies",
            'test_model_many_to_manies_link_only_url' => "/v2/test_models/#{test_model.guid}/test_model_many_to_manies_link_only"
          }
        )
      end

      describe 'to_one relationship' do
        let(:test_model_many_to_one) { VCAP::CloudController::TestModelManyToOne.make }

        it 'includes to_one relationship link when association is set' do
          test_model_many_to_one.test_model = test_model
          hash = subject.to_hash(VCAP::CloudController::TestModelManyToOnesController, test_model_many_to_one, opts, 0, [])
          expect(hash.fetch('test_model_url')).to eql("/v2/test_models/#{test_model.guid}")
        end

        it 'does not include to_one relationship link when association content is nil' do
          test_model_many_to_one.test_model
          hash = subject.to_hash(VCAP::CloudController::TestModelManyToOnesController, test_model_many_to_one, opts, 0, [])
          expect(hash).to_not have_key('test_model_url')
        end

        it 'raises NotLoadedAssociationError when association is not loaded and will be included so that this object is not responsible for checking authorization' do
          expect {
            subject.to_hash(VCAP::CloudController::TestModelManyToOnesController, test_model_many_to_one, opts, 0, [])
          }.to raise_error(CloudController::Errors::NotLoadedAssociationError, /test_model.*VCAP::CloudController::TestModelManyToOne/)
        end
      end

      describe 'to_many relationship' do
        let(:test_model_many_to_many) { VCAP::CloudController::TestModelManyToMany.make }
        it 'includes to_many relationship link when association is set' do
          test_model.add_test_model_many_to_many(test_model_many_to_many)
          hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts, 0, [])
          expect(hash.fetch('test_model_many_to_manies_url')).to eql("/v2/test_models/#{test_model.guid}/test_model_many_to_manies")
        end

        it 'includes to_many relationship link when association content is nil' do
          hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts, 0, [])
          expect(hash.fetch('test_model_many_to_manies_url')).to eql("/v2/test_models/#{test_model.guid}/test_model_many_to_manies")
        end

        it 'includes the association content when link_only is not specified' do
          test_model.add_test_model_many_to_many(test_model_many_to_many)
          hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts.merge(inline_relations_depth: 1), 0, [])
          expect(hash.fetch('test_model_many_to_manies_url')).to be
          expect(hash.fetch('test_model_many_to_manies')).to be
        end

        it 'does not include the association content when link_only is specified' do
          test_model.add_test_model_many_to_many(test_model_many_to_many)
          hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts.merge(inline_relations_depth: 1), 0, [])
          expect(hash.fetch('test_model_many_to_manies_link_only_url')).to be
          expect(hash).to_not have_key('test_model_many_to_manies_link_only')
        end

        it 'raises NotLoadedAssociationError when association is not loaded and will be included so that this object is not responsible for checking authorization' do
          test_model.reload
          test_model.remove_all_test_model_many_to_ones
          expect {
            subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts.merge(inline_relations_depth: 1), 0, [])
          }.to raise_error(CloudController::Errors::NotLoadedAssociationError, /test_model_many_to_manies.*VCAP::CloudController::TestModel/)
        end
      end

      it 'serializes related inline objects inline' do
        test_model_many_to_many = VCAP::CloudController::TestModelManyToMany.make
        test_model_second_level = VCAP::CloudController::TestModelSecondLevel.make
        test_model_many_to_many.test_model_second_levels.to_a
        test_model.add_test_model_many_to_many test_model_many_to_many
        test_model_many_to_many.add_test_model_second_level test_model_second_level

        hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts.merge(inline_relations_depth: 2), 0, [])
        expect(hash.fetch('test_model_many_to_manies')).to eql([
          'metadata' => {
            'guid' => test_model_many_to_many.guid,
            'url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}",
            'created_at' => test_model_many_to_many.created_at,
          },
          'entity' => {
            'test_model_second_levels_url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}/test_model_second_levels",
            'test_model_second_levels' => [
              {
                'metadata' =>
                  {
                    'guid' => test_model_second_level.guid,
                    'url' => "/v2/test_model_second_levels/#{test_model_second_level.guid}",
                    'created_at' => test_model_second_level.created_at
                  },
                'entity' => {}
              }
            ]
          }
        ])
      end

      describe 'orphan_relations enabled' do
        it 'serializes related n:many inline objects as orphans' do
          test_model_many_to_many = VCAP::CloudController::TestModelManyToMany.make
          test_model_second_level = VCAP::CloudController::TestModelSecondLevel.make
          test_model_many_to_many.test_model_second_levels.to_a
          test_model.add_test_model_many_to_many test_model_many_to_many
          test_model_many_to_many.add_test_model_second_level test_model_second_level

          orphans = {}
          hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts.merge(inline_relations_depth: 2), 0, [], orphans)
          expect(orphans.keys.size).to eql(2)
          expect(hash.fetch('test_model_many_to_manies')).to eql([test_model_many_to_many.guid])
          expect(orphans[test_model_many_to_many.guid]).to eql(
            'metadata' => {
              'guid' => test_model_many_to_many.guid,
              'url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}",
              'created_at' => test_model_many_to_many.created_at,
            },
            'entity' => {
              'test_model_second_levels_url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}/test_model_second_levels",
              'test_model_second_levels' => [test_model_second_level.guid]
            }
          )
          expect(orphans[test_model_second_level.guid]).to eql(
            'metadata' => {
              'guid' => test_model_second_level.guid,
              'url' => "/v2/test_model_second_levels/#{test_model_second_level.guid}",
              'created_at' => test_model_second_level.created_at
            },
            'entity' => {}
          )
        end

        it 'serializes related n:one inline objects as orphans' do
          test_model_many_to_one = VCAP::CloudController::TestModelManyToOne.make
          test_model_many_to_one.test_model = test_model

          orphans = {}
          hash = subject.to_hash(VCAP::CloudController::TestModelManyToOnesController, test_model_many_to_one, opts.merge(inline_relations_depth: 1), 0, [], orphans)
          expect(hash).not_to have_key 'test_model'
          expect(orphans.keys.size).to eql(1)
          expect(orphans[test_model_many_to_one.test_model.guid]).to eql(
            'metadata' => {
              'guid' => test_model_many_to_one.test_model.guid,
              'url' => "/v2/test_models/#{test_model_many_to_one.test_model.guid}",
              'created_at' => test_model_many_to_one.test_model.created_at,
              'updated_at' => test_model_many_to_one.test_model.updated_at
            },
            'entity' => {
              'unique_value' => test_model_many_to_one.test_model.unique_value,
              'sortable_value' => nil,
              'nonsortable_value' => nil,
              'test_model_many_to_ones_url' => "/v2/test_models/#{test_model_many_to_one.test_model.guid}/test_model_many_to_ones",
              'test_model_many_to_manies_url' => "/v2/test_models/#{test_model_many_to_one.test_model.guid}/test_model_many_to_manies",
              'test_model_many_to_manies_link_only_url' => "/v2/test_models/#{test_model_many_to_one.test_model.guid}/test_model_many_to_manies_link_only"
            }
          )
        end
      end

      it 'excludes relations named in exclude_relations' do
        test_model_many_to_many = VCAP::CloudController::TestModelManyToMany.make
        test_model_second_level = VCAP::CloudController::TestModelSecondLevel.make
        test_model_many_to_many.test_model_second_levels.to_a
        test_model.add_test_model_many_to_many test_model_many_to_many
        test_model_many_to_many.add_test_model_second_level test_model_second_level

        hash = subject.to_hash(VCAP::CloudController::TestModelsController, test_model, opts.merge(inline_relations_depth: 2, exclude_relations: 'test_model_second_levels'), 0, [])
        expect(hash.fetch('test_model_many_to_manies')).to eql([
          'metadata' => {
            'guid' => test_model_many_to_many.guid,
            'url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}",
            'created_at' => test_model_many_to_many.created_at,
          },
          'entity' => {
            'test_model_second_levels_url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}/test_model_second_levels"
          }
        ])
      end

      it 'only includes relations named in include_relations' do
        test_model_many_to_many = VCAP::CloudController::TestModelManyToMany.make
        test_model_second_level = VCAP::CloudController::TestModelSecondLevel.make
        test_model_many_to_many.test_model_second_levels.to_a
        test_model.add_test_model_many_to_many test_model_many_to_many
        test_model_many_to_many.add_test_model_second_level test_model_second_level

        hash = subject.to_hash(VCAP::CloudController::TestModelsController,
          test_model,
          opts.merge(inline_relations_depth: 2, include_relations: 'test_model_many_to_manies'),
          0,
          [])
        expect(hash.fetch('test_model_many_to_manies')).to eql([
          'metadata' => {
            'guid' => test_model_many_to_many.guid,
            'url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}",
            'created_at' => test_model_many_to_many.created_at,
          },
          'entity' => {
            'test_model_second_levels_url' => "/v2/test_model_many_to_manies/#{test_model_many_to_many.guid}/test_model_second_levels"
          }
        ])
      end
    end
  end
end
