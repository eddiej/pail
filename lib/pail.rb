require "pail/version"
require "pail/engine"

module Pail
  class Generate
    def self.signature(secret_access_key, policy)
      Base64.encode64(
        OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha1'), secret_access_key, policy)
      ).gsub("\n","")
    end

    def self.policy(bucket, expiration_date, acl, max_filesize)
      Base64.encode64(
        "{'expiration': '#{expiration_date}',
          'conditions': [
            {'bucket': '#{bucket}'},
            {'acl': '#{acl}'},
            {'success_action_status': '201'},
            ['content-length-range', 0, #{max_filesize}],
            ['starts-with', '$key', ''],
            ['starts-with', '$Content-Type', ''],
            ['starts-with', '$name', ''],
            ['starts-with', '$Filename', '']
          ]
        }"
      ).gsub(/\n|\r/, '')
    end
  end

  module PailHelper
    
    def pail(options = {})   
      # Read in the default bucket, AWS key and secret from environment variables.
 
      @bucket = ENV['S3_BUCKET']
      @access_key_id = ENV['AWS_ACCESS_KEY_ID']
      @secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
      @options = options.dup

      raise ArgumentError.new('a bucket, access key id and secret access key must be set') unless @bucket && @access_key_id && @secret_access_key

      @options[:key] ||= 'uploads' # folder on AWS to store file in
      @options[:acl] ||= 'public-read'
      @options[:expiration_date] ||= 10.hours.from_now.utc.iso8601
      @options[:max_filesize] ||= 104857600 # 100.megabytes
      @options[:content_type] ||= 'image/' # Videos would be binary/octet-stream
      @options[:filter_title] ||= 'Images'
      @options[:filter_extensions] ||= 'jpg,jpeg,gif,png,bmp'
      @options[:runtimes] ||= 'html5'

      @options[:selectid] ||= 'selectfile'
      @options[:cancelid] ||= 'resetupload'
      @options[:progress_bar_class] ||= 'progress-bar progress-bar-striped active'

      id = @options[:id] ? "_#{@options[:id]}" : ''

      policy = Pail::Generate::policy(
        @bucket,
        @options[:expiration_date], 
        @options[:acl], 
        @options[:max_filesize]
      )

      signature = Pail::Generate::signature(@secret_access_key, policy)

      out = ""
      filters = "filters : [
       {title : '#{@options[:filter_title]}', extensions : '#{@options[:filter_extensions]}'}
      ],"
      if @options[:filters]
        filters = 'filters : ['
        filters = filters + @options[:filters].join(',')
        filters = filters + "],"
      end


      out << javascript_tag(<<JAVASCRIPT
       
        uploader = new plupload.Uploader({
          browse_button : '#{@options[:selectid]}',
          container : 'uploadcontainer',
          runtimes : '#{@options[:runtimes]}',
          url : 'https://s3.amazonaws.com/#{@bucket}/',
          max_file_size : '#{number_to_human_size(@options[:max_filesize]).gsub(/ /,'').downcase}',
          multipart: true,
          multipart_params: {
            'key': '#{@options[:key]}/${filename}',
            'Filename': '${filename}', // adding this to keep consistency across the runtimes
            'acl': '#{@options[:acl]}',
            'Content-Type': '#{@options[:content_type]}',
            'success_action_status': '201',
            'AWSAccessKeyId' : '#{@access_key_id}',
            'policy': '#{policy}',
            'signature': '#{signature}'
          },
          // optional, but better be specified directly
          file_data_name: 'file',
          // re-use widget (not related to S3, but to Plupload UI Widget)
          multiple_queues: true,
          // Specify what files to browse for
          #{filters}
          // Flash settings
          flash_swf_url : '/assets/plupload/Moxie.swf',
          // Silverlight settings
          silverlight_xap_url : '/assets/plupload/Moxie.xap',
        });

        placeholder = $('#uploadfile').children().first();
        uploader.init() 
        var queueMaxima = 1;

        // 1. Files Added          
        uploader.bind('FilesAdded', function(up, files) {           
          $.each(files, function(i, file) {
            $('#uploadfile').empty().append(' \
              <div id="' + file.id + '" class="progress"> \
                <div class="#{@options[:progress_bar_class]}" role="progressbar" aria-valuenow="'+file.percent+'" aria-valuemin="0" aria-valuemax="100"> \
                  <span class="file-info">' + file.name + ' (' + plupload.formatSize(file.size) + ')</span>' +
                '</div> \
              </div>');
          });
          $('##{@options[:cancelid]}').removeClass('disabled')


            
          if(uploader.files.length > queueMaxima){
            while(uploader.files.length > queueMaxima){
              if(uploader.files.length > queueMaxima){
                x = uploader.files[queueMaxima-1]
                
                $('#'+x.id).remove();
                uploader.removeFile(uploader.files[queueMaxima-1]);
                uploader.stop()
              }
            }
            if(typeof(plupload_hook_removedExcessFromQueue) == "function"){plupload_hook_removedExcessFromQueue()}
          }
          up.start();
          up.refresh(); // Reposition Flash/Silverlight
        });

        // 2. Right before Upload Starts
        uploader.bind('BeforeUpload', function(up, file) {
          $('#' + file.id + " .progress-bar")
            .addClass('active')
        });

        // 2. Upload Progresses
        uploader.bind('UploadProgress', function(up, file) {
          $('#' + file.id + " .progress-bar")
            .width(file.percent + "%")
            .html('<span class="file-info">' + file.name + ' (' + plupload.formatSize(file.size) + ') ' + file.percent + "%</span>");
        });

        // 3. Error Occurs
        uploader.bind('Error', function(up, err) {  
          if($('.file-info').length > 0){
            error_element = $('.file-info')
          }
          else{
            error_element = $('.progress')
          }
          error_element.html("Error: " + err.code + ", " + err.message + (err.file ? " File: " + err.file.name : ""));
          $('#' + err.file.id + " .progress-bar")
            .addClass('progress-bar-danger')
            .removeClass('active')
        });

        // 4. File is Uploaded
        uploader.bind('FileUploaded', function(up, file) {
          $('#' + file.id + " .progress-bar")
            .addClass('progress-bar-success')
            .removeClass('active')
        });

        // 5. Stop button is clicked.
        $('#uploadcontainer').on('click', '##{@options[:cancelid]}', function(){
          uploader.stop();
          $('#uploadfile').html(placeholder);
          $('##{@options[:cancelid]}').addClass('disabled')
          $('#' + file.id + " .progress-bar")
            .removeClass('active')
          uploader.refresh(); // Reposition Flash/Silverlight
        });

        window.uploader = uploader;
JAVASCRIPT
)

     raw(out);
    end
  end
  ActionView::Base.send :include, PailHelper
end