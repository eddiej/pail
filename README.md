# Pail

Pail is a Ruby gem that makes it easy to upload files directly to an Amazon S3 Bucket, bypassing your application server. 

It uses the Plupload JavaScript uploader originally written for PHP, bundling the necessary Javascript libraries with convenience methods for generating the policy document and SHA1 signature required to upload to S3. Pail applies Twitter Boostrap progress-bar styling to the uploader, but it can be left unstyled and customised at will.

## Why Do I Need It?

There are two approaches to processing and storing file uploads from your Rails app to S3: pass-through uploading and direct uploading. 

**Pass-through uploading**, which sends files to your Rails application before uploading them from there to S3 storage, is easy to implement, but your application's server threads will be tied up during the upload process which can have a blocking affect on your application. 

If all of the available threads of your server are occupied by slow uploads, your application will become unavailable until one of the uploads finishes and frees up a thread. Some hosting providers like Heroku terminate requests that last longer than 30 seconds, so uploads that take any longer won't complete.

**Direct uploading** makes a direct connection between the end-user's browser and S3, so it doesn't touch your application at all. This will greatly reduce the processing required by your application and keep your threads free for other requests, but it can be complicated to implement. See [Heroku's Guide for direct uploading to S3 with Rails](https://devcenter.heroku.com/articles/direct-to-s3-image-uploads-in-rails) to see just how complicated.

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

When you call the `Pail()` method, the gem will generate the policy using your private key and secret and inject the encrypted values into the configuration hash on your page. This means that your sensitive information doesn't get exposed on the front-end.

### Signature Generation
In addition to sending a Policy document, each request must also be signed with a HMAC-SHA1 encrypted and Base64 encoded signature which is created from you AWS Secret Access Key. Pail will generate the signature for you and insert the encryoted values into the configuration hash on the front-end.

## Creating an Uploader

Inserting an uploader onto a page is as simple as calling the `Pail()` function in a view template. In an ERB file, this would be:

```ruby
<%= pail() %>
```

This will insert the required markup to display the file select buttons and create an placeholder to display information about the file being uploaded and progress bar. Pail uses classes from Twitter Bootstrap in the default markup:

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

You can use your own markup as long as you include the three elements required by Pail:

- an element in which to place the progresss bar
- a 'select file' button
- a 'reset' button. 

The default ID's for each of these elements is `#uploadfile`, `#selectfile` and `#resetupload`, but these can be overridden via the options hash.
    
Any placeholder content can be placed within the `#uploadfile` element as long as it is wrapped in a containing element. By default, an empty div with the class 'progress' is inserted which displays an empty progress bar well. This will be replaced with a progress bar once a file is selected and put back again if the upload is reset. 

### Upload Progress

The upload progress bar itself is the same as that used by [Twitter Bootstap progress bars](http://getbootstrap.com/components/#progress):

```html
<div class="progress">
 <div class="progress-bar" role="progressbar" aria-valuenow="75" aria-valuemin="0" aria-valuemax="100" style="width: 75%;">
   <span class="file-info">Moonshine.jpg (453 kb) 75% </span>
 </div>
</div>
```

The control buttons and progress bar will be unstyled by default, but you can apply the Boostrap styles by including the Pail stylesheet from application.css:

```css
*
*= require_tree .
*= require_self
*= require pail
*/ 
```

If you already use Twitter Bootstrap in your application, the styles from your theme will automatically be applied.
The resulting uploader will look like this once a file has been selected:

`![Alt Image Text](./in_progress.png "Optional Title")`


## Upload Events

Plupload defines a number of events that can be bound to, a full list of which can be found on the Plupload WIKI. By default, Pail uses event binding to change the style of the progress bar according to the state of the uploader and to write the uploaded file URL to the dom as a data attribute of the `#uploadfile` element once an upload completes.

Additional functionality would generally be bound to the FileUploadaed event to perform additional actions once a file has been uploaded. Examples might include:

- Insert the S3 url of the uploaded file into a hidden field and submit a form.
- Send the S3 url to a controller via a remote AJAX call
- Redirect to another page that displays the uploaded asset 

To bind additional events, 
Thse would be written after the plupload function is called. 