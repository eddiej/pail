require 'spec_helper'

describe Pail do
  it 'has a version number' do
    expect(Pail::VERSION).not_to be nil
  end

  describe Pail::Generate do
    describe 'signature' do
      it 'generates a one way hash' do
        expect(Pail::Generate::signature('a', 'b')).to eq ('ZleFVoaCOYbIdDYnMROXUgFMtgs=')
      end
    end
    describe 'policy' do
      before do
        @policy = Pail::Generate::policy('a', 'b', 'c', 1)
        @expected_result = 
          {'expiration': 'b',
            'conditions': [
              {'bucket': 'a'},
              {'acl': 'c'},
              {'success_action_status': '201'},
              ['content-length-range', 0, 1],
              ['starts-with', '$key', ''],
              ['starts-with', '$Content-Type', ''],
              ['starts-with', '$name', ''],
              ['starts-with', '$Filename', '']
            ]
          }

      end
      it 'generates a Base64 encoded json object' do  
        expect( eval( Base64.decode64(@policy) )).to eq @expected_result
      end
    end
  end

  describe Pail::PailHelper, type: :helper do
    context 'configuration variables missing' do
      it "raises an exception if the required env vars are missing missing" do
        expect{helper.pail()}
          .to raise_error(ArgumentError, 
            "a bucket, access key id and secret access key must be set")
      end
    end
    context 'configuration variables present', :focus do
      before do
        ENV.stub(:[]).with('S3_BUCKET').and_return('somebucket.example.com')
        ENV.stub(:[]).with('AWS_ACCESS_KEY_ID').and_return('someaccesskeyid')
        ENV.stub(:[]).with('AWS_SECRET_ACCESS_KEY').and_return('somesecretaccesskey')
        @output = helper.pail()
      end

      it 'returns javascript output' do
        expect(@output).to start_with("<script>")
      end
      
      it 'sets bucket config variables' do
        expect(helper.instance_variable_get(:@bucket)).to eq 'somebucket.example.com'
        expect(helper.instance_variable_get(:@access_key_id)).to eq 'someaccesskeyid'
        expect(helper.instance_variable_get(:@secret_access_key)).to eq 'somesecretaccesskey'

      end

      it 'sets @options with defaults' do
        @options = helper.instance_variable_get(:@options)
        
        expect(@options).to be_a Hash
        expect(@options[:key]).to eq 'uploads'
        expect(@options[:acl]).to eq 'public-read'
        expect(@options[:expiration_date]).to be <= 10.hours.from_now.utc.iso8601
        expect(@options[:max_filesize]).to eq 104857600
        expect(@options[:content_type]).to eq 'image/'
        expect(@options[:filter_title]).to eq 'Images'
        expect(@options[:filter_extensions]).to eq 'jpg,jpeg,gif,png,bmp'
        expect(@options[:runtimes]).to eq 'html5'

        expect(@options[:selectid]).to eq 'selectfile'
        expect(@options[:cancelid]).to eq 'resetupload'
        expect(@options[:progress_bar_class]).to eq 'progress-bar progress-bar-striped active'
      end
    end
  end
end