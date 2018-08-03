require 'spec_helper'

RSpec.describe VCAP::CloudController::DB do

  describe '.get_database_scheme' do
    context 'with only a database connection string for mysql' do
      it 'should return that the database is MySQL' do
        scheme = VCAP::CloudController::DB.get_database_scheme({
          database: 'mysql2://cloud_controller:p4ssw0rd@sql-db.service.cf,.internal:3306/cloud_controller'
        })

        expect(scheme).to eq('mysql')
      end
    end

    context 'with only a database connection string for postgres' do
      it 'should return that the database is Postgres' do
        scheme = VCAP::CloudController::DB.get_database_scheme({
          database: 'postgres://cloud_controller:p4ssw0rd@sql-db.service.cf.internal:5524/cloud_controller'
        })

        expect(scheme).to eq('postgres')
      end
    end

    context 'when database_parts is also present in the config' do
      it 'takes precedence over any database connection string' do
        scheme = VCAP::CloudController::DB.get_database_scheme({
          database: 'postgres://cloud_controller:p4ssw0rd@sql-db.service.cf.internal:5524/cloud_controller',
          database_parts: {
            adapter: 'foo'
          }
        })

        expect(scheme).to eq('foo')
      end

      context 'when the adapter specifies mysql2' do
        it 'should return that the database is mysql' do
          scheme = VCAP::CloudController::DB.get_database_scheme({
            database: 'mysql2://cloud_controller:p4ssw0rd@sql-db.service.cf,.internal:3306/cloud_controller',
            database_parts: {
              adapter: 'mysql2'
            }
          })

          expect(scheme).to eq('mysql')
        end
      end

      context 'when the adapter specifies postgres' do
        it 'should return that the database is Postgres' do
          scheme = VCAP::CloudController::DB.get_database_scheme({
            database: 'database-connection-postgres://cloud_controller:p4ssw0rd@sql-db.service.cf.internal:5524/cloud_controller',
            database_parts: {
              adapter: 'postgres'
            }
          })

          expect(scheme).to eq('postgres')
        end
      end
    end
  end
end
