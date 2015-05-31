# Pail

Pail is a Ruby gem that makes it easy to upload files directly from your views to an Amazon S3 Bucket, bypassing your application server. 

![Alt Image Text](https://raw.githubusercontent.com/eddiej/pail/gh-pages/in_progress.png "Optional Title")

It uses the Plupload JavaScript uploader originally written for PHP, bundling the required Javascript libraries with convenience methods for generating the policy document and SHA1 signature needed to upload to S3. 
Pail has the option of applying Twitter Boostrap progress-bar styling to the uploader, but it is unstyled by default.


## Why Do I Need It?

To avoid blocking your server during file uploads. There are two approaches to processing and storing file uploads from your Rails app to S3: pass-through uploading and direct uploading. 

**Pass-through uploading**, which sends files to your Rails application before uploading them from there to S3 storage, is easy to implement, but your application's server threads will be tied up during the upload process which can have a blocking effect on your application. 

If all of the available threads of your server are occupied by slow uploads, your application will become unavailable until one of the uploads finishes and frees up a thread. Some hosting providers like Heroku terminate requests that last longer than 30 seconds, so uploads that take any longer won't complete.

**Direct uploading** makes a direct connection between the end-user's browser and S3, bypassing your application entirely. This will greatly reduce the processing required by your application and keep your threads free for other requests, but it can be complicated to implement. See [Heroku's Guide for direct uploading to S3 with Rails](https://devcenter.heroku.com/articles/direct-to-s3-image-uploads-in-rails) for an example implementation.

Pail takes the complication out of direct uploading, allowing users to create a direct uploader with just one line of code.


## Requirements

Before you can upload to S3, you'll need to:

- create a bucket
- configure the bucket to allow uploads
- generate a Base64 encoded Policy document
- generate a Base64 encoded SHA1 encrypted signature

Your S3 bucket needs to be created and configured manually, but Pail looks after the the policy document and signature generation. Pail needs access to three variables; the name of the bucket you'll be uploading to, an AWS access key id and secret access key. These should be made available as environrment variables in your Rails app: 

```ruby
ENV['S3_BUCKET']=assets.mydomain.com
ENV['AWS_ACCESS_KEY_ID']=AKIAJLAP2FSKJEBDFLWWA
ENV['AWS_SECRET_ACCESS_KEY']=KKdkahb4kdfheb4KGcII8iRzpFymlUanYGszLf1U
```

### Configuring Your S3 Bucket

Plupload provides a number of different runtimes including HTML5, Flash and Sliverlight. Depending on the runtime you wish to use, the configuration settings are slightly different. Configuring your S3 Bucket for the three main runtimes is documented below, see the [Plupload documentation](http://www.plupload.com/docs/Upload-to-Amazon-S3) for a more detailed explanation.

#### HTML5 Runtime

To use the HTML5 Runtime, you must add a CORS configuration similar to the one below in the `Permissions` section of the S3 bucket options. This is accessed from your S3 dashboard.

```xml
<CORSConfiguration>
    <CORSRule>
        <AllowedOrigin>*</AllowedOrigin>
        <AllowedHeader>*</AllowedHeader>
        <AllowedMethod>GET</AllowedMethod>
        <AllowedMethod>POST</AllowedMethod>
        <MaxAgeSeconds>3000</MaxAgeSeconds>
    </CORSRule>
</CORSConfiguration>
```


#### Flash Runtime

Flash requires a `crossdomain.xml` policy file to be present at the root of your bucket to support cross-origin requests:

```xml
<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM
"http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
 <allow-access-from domain="*" secure="false" />
</cross-domain-policy>
```

#### Silverlight Runtime

Silverlight uses its own Security Policy File - `clientaccesspolicy.xml`, but when all domains are allowed, it can fallback to `crossdomain.xml`.

See the [Plupload documentation](http://www.plupload.com/docs/Upload-to-Amazon-S3#for-silverlight-runtime) for more information on generating `clientaccesspolicy.xml` for allowing only specific domains.


### Policy Generation

In order to upload to S3, each request musy be accompanied with a Base64 encoded policy, a set of rules your request should conform to. Amazon will reject requests with missing or invalid policy documents and respond with a 403 Forbidden error.

When you call the `pail()` function, the gem will generate the policy using your private key and secret and inject the encrypted values into the configuration hash on your page. This means that your sensitive information doesn't get exposed on the front-end.

### Signature Generation
In addition to sending a Policy document, each request must also be signed with a HMAC-SHA1 encrypted and Base64 encoded signature which is created from you AWS Secret Access Key. Pail will generate the signature for you and insert the encryoted values into the configuration hash on the front-end.

## Creating an Uploader

To use the Pail, add the Gem to your Gemfile and include the Pail Javascript in your `application.js` file. Note that jQuery is a pre-requisite for Pail.

<pre>
//= require jquery
//= require jquery_ujs
//= require turbolinks
//= require_tree .
<b>//= require pail</b>
</pre>



Inserting an uploader onto a page is as simple as including a small amount of HTML markup and calling the `pail()` function in a view template. In an ERB file, this would look like:

```ruby
<%= pail() %>
```

Your HTML markup must provide:

- a file select button
- a cancel button
- a placeholder element that will display information about the file being uploaded 

The default IDs for each of these elements is `#selectfile`, `#resetupload`, and `#uploadfile` but these can be overridden via the options hash. The markup below contains the required elements:

```html
<div id='uploadcontainer'>
 <h3>Upload A File</h3>
 <div id='uploadfile'> 
   <div class="progress"></div>
 </div>
 <button type="button" class="btn btn-default btn btn-sm" id="selectfile">Select File</button>
 <button type="button" class="btn btn-danger btn btn-sm disabled" id="resetupload">Reset</button>
</div>
```


    
Any placeholder content can be placed within the `#uploadfile` element as long as it is wrapped in a containing element. By default, an empty div with the class 'progress' is inserted which displays an empty progress bar well. This will be replaced with a progress bar once a file is selected and put back again if the upload is reset. 

### Parameters

Custom options can be sent in a hash parameter of the `pail()` function. The options currently configurable in Pail and their default values are:

```ruby
options[:key] ||= 'test' 
options[:acl] ||= 'public-read'
options[:expiration_date] ||= 10.hours.from_now.utc.iso8601
options[:max_filesize] ||= 500.kilabytes
options[:content_type] ||= 'image/'
options[:filter_title] ||= 'Images'
options[:filter_extentions] ||= 'jpg,jpeg,gif,png,bmp'
options[:runtimes] ||= 'html5'
options[:selectid] ||= 'selectfile'
options[:cancelid] ||= 'resetupload'
options[:progress_bar_class] ||= 'progress-bar progress-bar-striped active'       
```

The [Plupload Options documentation](http://www.plupload.com/docs/Options) should be referred to for explanations of each value. The `selectid`, `cancelid` and `progress_bar_class` values are relevant only to Pail and not Plupload.

### Upload Progress

The upload progress bar uses the same markup as the [Twitter Bootstap progress bar](http://getbootstrap.com/components/#progress).

```html
<div class="progress">
 <div class="progress-bar" role="progressbar" aria-valuenow="60" aria-valuemin="0" aria-valuemax="100" style="width: 60%;">
   <span class="file-info">Moonshine.jpg (453 kb) 60% </span>
 </div>
</div>
```

The control buttons and progress bar will be unstyled by default, but you can apply the Boostrap styles by including the Pail stylesheet from `application.css`:

<pre>
*
*= require_tree .
*= require_self
<b>*= require pail</b>
*/ 
</pre>

If you already use Twitter Bootstrap in your application, the styles from your theme will automatically be applied.

## Upload Events

Plupload defines a number of events that can be bound to, a full list of which can be found in the [Plupload documentation](http://www.plupload.com/docs/Uploader#events). By default, Pail uses event binding to change the style of the progress bar according to the state of the uploader.

Additional functionality would generally be bound to the FileUploadaed event to perform additional actions once a file has been uploaded. Examples might include:

- Insert the S3 url of the uploaded file into a hidden field and submit a form.
- Send the S3 url to a controller via a remote AJAX call
- Redirect to another page that displays the uploaded asset 

To bind additional events, use the jQuery `bind` function after `<%= pail %>` has been called. 

```javascript
<script>
  window.uploader.bind('FileUploaded', function(up, file, info) { alert (info); })
</script>
```

Note that the uploader object created by the Plupload Javascript is added as a property of the window object and can be accessed by `window.uploader`.

The default Pail events can be removed using the `unbind` function, e.g:

```javascript
<script>
  window.uploader.unbind('UploadProgress')
  window.uploader.unbind('FileUploaded')
  ...
</script>
```

## Testing
The tests for the gem are written in Rspec:

    bundle exec rspec spec

 