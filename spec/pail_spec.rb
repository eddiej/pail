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
end