require 'spec_helper'

RSpec.describe 'DnsApi::Routes::DNS' do
  def app
    @app ||= DnsApi::Routes::DNS
  end

  describe 'v1 API' do
    prefix = '/v1/dns'

    describe "when GET #{prefix}/ping" do
      subject { get "#{prefix}/ping" }
      it 'returns pong' do
        expect(subject.status).to eq(200)
        expect(subject.body).to eq('pong')
      end
    end

    describe "when GET #{prefix}/version" do
      subject { get "#{prefix}/version" }
      it 'returns v0.0.1-dev' do
        expect(subject.status).to eq(200)
        expect(subject.body).to eq({ 'version' => 'v0.0.1-dev' }.to_json)
      end
    end

    describe "when OPTIONS #{prefix}/version" do
      subject { options "#{prefix}/version" }
      it 'return CORS headers' do
        expect(subject.status).to eq(200)
        expect(subject.header['Access-Control-Allow-Origin']).to eq('*')
      end
    end

    describe "when GET #{prefix}" do
      subject do
        header 'Auth-Token', 'test'
        get prefix
      end
      it 'status code 200 and includes test account' do
        expect(subject.status).to eq(200)
        expect(subject.body).to include('bam-test')
      end
    end

    describe "when GET #{prefix}/:account/id/:id" do
      let(:route) { "#{prefix}/bam-test/id/12345" }

      context 'non-existent account' do
        subject do
          header 'Auth-Token', 'test'
          get "#{prefix}/bork/id/12345"
        end
        it 'status code 404' do
          expect(subject.status).to eq(404)
        end
      end

      context 'valid account' do
        subject do
          header 'Auth-Token', 'test'
          get route
        end
        it 'returns supported resources' do
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
  end
end
