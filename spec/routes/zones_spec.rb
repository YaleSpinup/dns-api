require 'spec_helper'

RSpec.describe 'DnsApi::Routes::DNS' do
  def app
    @app ||= DnsApi::Routes::DNS
  end

  describe 'v1 API' do
    prefix = '/v1/dns'
    describe "when GET #{prefix}/:account/zones" do
      let(:route) { "#{prefix}/bam-test/zones" }
      context 'non-existent account' do
        subject do
          header 'Auth-Token', 'test'
          get "#{prefix}/bork/zones"
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
          header 'Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'Auth-Token', 'test'
          get route, 'hint' => 'example.com'
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_entities).and_return([entity])
          expect(entity).to receive(:id).and_return('12345')
          expect(client).to receive(:get_zones_by_hint).with('12345', 0, 10, 'hint=example.com').and_return([entity])
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end
    end

    describe "when GET #{prefix}/:account/zones/:id" do
      let(:route) { "#{prefix}/bam-test/zones/12345" }
      context 'non-existent account' do
        subject do
          header 'Auth-Token', 'test'
          get "#{prefix}/bork/zones/12345"
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
          header 'Auth-Token', 'bork'
          get route
        end

        it 'status code 401' do
          expect(subject.status).to eq(401)
        end
      end

      context 'with valid token' do
        subject do
          header 'Auth-Token', 'test'
          get route
        end

        it 'status code 200' do
          client = double('proteus client')
          entity = double('api entity')
          expect(Proteus::Client).to receive(:new).and_return(client)
          expect(client).to receive(:login!).and_return(client)
          expect(client).to receive(:get_entity_by_id).with('12345').and_return(entity)
          expect(entity).to receive(:type).and_return('Zone')
          expect(entity).to receive(:to_h)
          expect(subject.status).to eq(200)
        end
      end
    end
  end
end
