require 'spec_helper'

RSpec.describe 'DnsApi::Routes::DNS' do
  def app
    @app ||= DnsApi::Routes::DNS
  end

  describe 'v1 API' do
    prefix = '/v1/dns'
    valid_token = '$2a$10$mLHLxLBpK0Ile.nNvilpu.nkHyZPL0NDtdbDbTH/QEP7yypEvlfCK'

    describe "when GET #{prefix}/:account/records" do
      let(:route) { "#{prefix}/bam-test/records" }
      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          get "#{prefix}/bork/records"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with unset record type' do
        subject do
          header 'X-Auth-Token', valid_token
          get route
        end

        it 'status code 400' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(subject.status).to eq(400)
        end
      end

      context 'with HostRecord type' do
        subject do
          header 'X-Auth-Token', valid_token
          get route, 'type' => 'HostRecord', 'hint' => 'some.example.com'
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_host_records_by_hint).with(0, 10, 'hint=some.example.com').and_return([entity])
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end

      context 'with AliasRecord type' do
        subject do
          header 'X-Auth-Token', valid_token
          get route, 'type' => 'AliasRecord', 'hint' => 'some.example.com'
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_aliases_by_hint).with(0, 10, 'hint=some.example.com').and_return([entity])
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end

      context 'with ExternalHostRecord type and name parameter' do
        subject do
          header 'X-Auth-Token', valid_token
          get route, 'type' => 'ExternalHostRecord', 'name' => 'some.example.com'
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_entity_by_name).with(
            123456, 'some.example.com', 'ExternalHostRecord'
          ).and_return(entity)
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end

      context 'with ExternalHostRecord type and keyword parameters' do
        subject do
          header 'X-Auth-Token', valid_token
          get route, 'type' => 'ExternalHostRecord', 'keyword' => 'foobar'
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:search_by_object_types).with('foobar', 'ExternalHostRecord', 0, 10).and_return([entity])
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end

      context 'with ExternalHostRecord type and no parameters' do
        subject do
          header 'X-Auth-Token', valid_token
          get route, 'type' => 'ExternalHostRecord'
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_entities).with(123456, 'ExternalHostRecord', 0, 10).and_return([entity])
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end
    end

    describe "when GET #{prefix}/:account/records/:id" do
      let(:route) { "#{prefix}/bam-test/records/12345" }
      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          get "#{prefix}/bork/records/12345"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          get route
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_entity_by_id).with('12345').and_return(entity)
          expect(entity).to receive(:type).and_return('HostRecord')
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end
    end

    describe "when POST #{prefix}/:account/records" do
      let(:route) { "#{prefix}/bam-test/records" }
      let(:hostparams) { { 'type' => 'HostRecord', 'record' => 'foo.example.com', 'target' => '192.168.1.23' } }
      let(:externalparams) { { 'type' => 'ExternalHostRecord', 'record' => 'foo.example.com' } }
      let(:aliasparams) { { 'type' => 'AliasRecord', 'record' => 'foo.example.com', 'target' => 'bar.example.com' } }
      let(:badtype) { { 'type' => 'FoobarRecord' } }

      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          get "#{prefix}/bork/records"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'AliasRecord with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, aliasparams.to_json
        end

        it 'returns status code 200' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:add_alias_record).with('foo.example.com', 'bar.example.com', 300, '').and_return('123456')
          expect(subject.status).to eq(200)
        end
      end

      context 'ExternalHostRecord with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, externalparams.to_json
        end

        it 'returns status code 200' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:add_external_host_record).with('foo.example.com', '').and_return('123456')
          expect(subject.status).to eq(200)
        end
      end

      context 'HostRecord with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, hostparams.to_json
        end

        it 'returns status code 200' do
          client = double('proteus client')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:add_host_record).with('foo.example.com', '192.168.1.23', 300, '').and_return('123456')
          expect(subject.status).to eq(200)
        end
      end

      context 'with empty body' do
        subject do
          header 'X-Auth-Token', valid_token
          post route
        end
        it 'status code 400' do
          expect(subject.status).to eq(400)
        end
      end

      context 'with bad json params' do
        subject do
          header 'X-Auth-Token', valid_token
          post route, badtype.to_json
        end
        it 'status code 422' do
          expect(subject.status).to eq(422)
        end
      end
    end

    describe "when DELETE #{prefix}/:account/records/:id" do
      let(:route) { "#{prefix}/bam-test/records/12345" }
      context 'non-existent account' do
        subject do
          header 'X-Auth-Token', valid_token
          delete "#{prefix}/bork/records/12345"
        end

        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'without token' do
        subject { get route }
        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with invalid token' do
        subject do
          header 'X-Auth-Token', 'bork'
          delete route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'X-Auth-Token', valid_token
          delete route
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:delete).with('12345').and_return(entity)
          expect(subject.status).to eq(200)
        end
      end
    end
  end
end
