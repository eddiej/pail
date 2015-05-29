# Pail

Pail is a Ruby gem that makes it easy to upload files directly to an Amazon S3 Bucket, bypassing your application server. 

It uses the Plupload JavaScript uploader originally written for PHP, bundling the necessary Javascript libraries with convenience methods for generating the policy document and SHA1 signature required to upload to S3. Pail applies Twitter Boostrap progress-bar styling to the uploader, but it can be left unstyled and customised at will.

## Why Do I Need It?

There are two approaches to processing and storing file uploads from your Rails app to S3: direct uploading and pass-through uploading.

**Pass-through uploading**, which sends files to your Rails application before uploading them from there to S3 storage, is easy to implement -it can be done using just a simple form - but your application's server threads will be tied up during the upload process which can have a blocking affect on your application. If all of the available threads of your server are occupied by slow uploads, your application will become unavailable until one of the uploads finishes and frees up a thread. Some hosting providers like Heroku terminate requests that last longer than 30 seconds, so uploads that take any longer won't complete.

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
*= include pail.css
```

If you already use Twitter Bootstrap in your application, the styles from your theme will automatically be applied.
The resulting uploader will look like this once a file has been selected:

`![Alt Image Text](path/or/url/to.jpg "Optional Title")`


## Upload Events

Plupload defines a number of events that can be bound to, a full list of which can be found on the Plupload WIKI. By default, Pail uses event binding to change the style of the progress bar according to the state of the uploader and to write the uploaded file URL to the dom as a data attribute of the `#uploadfile` element once an upload completes.

Additional functionality would generally be bound to the FileUploadaed event to perform additional actions once a file has been uploaded. Examples might include:

- Insert the S3 url of the uploaded file into a hidden field and submit a form.
- Send the S3 url to a controller via a remote AJAX call
- Redirect to another page that displays the uploaded asset 

To bind additional events, 
Thse would be written after the plupload function is called. 




## Markdown and I

**Markdown** is a plain text formatting syntax created by John Gruber, aiming to provide a easy-to-read and feasible markup. The original Markdown syntax specification can be found [here](http://daringfireball.net/projects/markdown/syntax).

**MacDown** is created as a simple-to-use editor for Markdown documents. I render your Markdown contents real-time into HTML, and display them in a preview panel.

![MacDown Screenshot](http://d.pr/i/10UGP+)

I support all the original Markdown syntaxes. But I can do so much more! Various popular but non-standard syntaxes can be turned on/off from the [**Markdown** preference pane](#markdown-pane).

You can specify extra HTML rendering options through the [**Rendering** preference pane](#rendering-pane).

You can customize the editor window to you liking in the [**Editor** preferences pane](#editor-pane):

You can configure various application (that's me!) behaviors in the [**General** preference pane](#general-pane).

## The Basics
Before I tell you about all the extra syntaxes and capabilities I have, I'll introduce you to the basics of standard markdown. If you already know markdown, and want to jump straight to learning about the fancier things I can do, I suggest you skip to the [**Markdown** preference pane](#markdown-pane). Lets jump right in.  

### Line Breaks
To force a line break, put two spaces and a newline (return) at the end of the line.

	These lines
	won't break

	These lines  
	will break


### Strong and Emphasize

**Strong**: `**Strong**` or `__Strong__` (Command-B)  
*Emphasize*: `*Emphasize*` or `_Emphasize_`[^emphasize] (Command-I)

### Headers (like this one!)

	Header 1
	========

	Header 2
	--------

or

	# Header 1
	## Header 2
	### Header 3
	#### Header 4
	##### Header 5
	###### Header 6



### Links and Email
#### Inline
Just put angle brackets around an email and it becomes clickable: <uranusjr@gmail.com>  
`<uranusjr@gmail.com>`  

Same thing with urls: <http://macdown.uranusjr.com>  
` <http://macdown.uranusjr.com>`  

Perhaps you want to some link text like this: [Macdown Website](http://macdown.uranusjr.com "Title")  
`[Macdown Website](http://macdown.uranusjr.com "Title")` (The title is optional)  


#### Reference style
Sometimes it looks too messy to include big long urls inline, or you want to keep all your urls together.  

Make [a link][arbitrary_id] `[a link][arbitrary_id]` then on it's own line anywhere else in the file:  
`[arbitrary_id]: http://macdown.uranusjr.com "Title"`
  
If the link text itself would make a good id, you can link [like this][] `[like this][]`, then on it's own line anywhere else in the file:  
`[like this]: http://macdown.uranusjr.com`  

[arbitrary_id]: http://macdown.uranusjr.com "Title"
[like this]: http://macdown.uranusjr.com  


### Images
#### Inline
`![Alt Image Text](path/or/url/to.jpg "Optional Title")`
#### Reference style
`![Alt Image Text][image-id]`  
on it's own line elsewhere:  
`[image-id]: path/or/url/to.jpg "Optional Title"`


### Lists

* Lists must be preceded by a blank line (or block element)
* Unordered lists start each item with a `*`
- `-` works too
	* Indent a level to make a nested list
		1. Ordered lists are supported.
		2. Start each item (number-period-space) like `1. `
		42. It doesn't matter what number you use, I will render them sequentially
		1. So you might want to start each line with `1.` and let me sort it out

Here is the code:

```
* Lists must be preceded by a blank line (or block element)
* Unordered lists start each item with a `*`
- `-` works too
	* Indent a level to make a nested list
		1. Ordered lists are supported.
		2. Start each item (number-period-space) like `1. `
		42. It doesn't matter what number you use, I will render them sequentially
		1. So you might want to start each line with `1.` and let me sort it out
```



### Block Quote

> Angle brackets `>` are used for block quotes.  
Technically not every line needs to start with a `>` as long as
there are no empty lines between paragraphs.  
> Looks kinda ugly though.
> > Block quotes can be nested.  
> > > Multiple Levels
>
> Most markdown syntaxes work inside block quotes.
>
> * Lists
> * [Links][arbitrary_id]
> * Etc.

Here is the code:

```
> Angle brackets `>` are used for block quotes.  
Technically not every line needs to start with a `>` as long as
there are no empty lines between paragraphs.  
> Looks kinda ugly though.
> > Block quotes can be nested.  
> > > Multiple Levels
>
> Most markdown syntaxes work inside block quotes.
>
> * Lists
> * [Links][arbitrary_id]
> * Etc.
```
  
  
### Inline Code
`Inline code` is indicated by surrounding it with backticks:  
`` `Inline code` ``

If your ``code has `backticks` `` that need to be displayed, you can use double backticks:  
```` ``Code with `backticks` `` ````  (mind the spaces preceding the final set of backticks)


### Block Code
If you indent at least four spaces or one tab, I'll display a code block.

	print('This is a code block')
	print('The block must be preceded by a blank line')
	print('Then indent at least 4 spaces or 1 tab')
		print('Nesting does nothing. Your code is displayed Literally')

I also know how to do something called [Fenced Code Blocks](#fenced-code-block) which I will tell you about later.

### Horizontal Rules
If you type three asterisks `***` or three dashes `---` on a line, I'll display a horizontal rule:

***


## <a name="markdown-pane"></a>The Markdown Preference Pane
This is where I keep all preferences related to how I parse markdown into html.  
![Markdown preferences pane](http://d.pr/i/RQEi+)

### Document Formatting
The ***Smartypants*** extension automatically transforms straight quotes (`"` and `'`) in your text into typographer’s quotes (`“`, `”`, `‘`, and `’`) according to the context. Very useful if you’re a typography freak like I am. Quote and Smartypants are syntactically incompatible. If both are enabled, Quote takes precedence.


### Block Formatting

#### Table

This is a table:

First Header  | Second Header
------------- | -------------
Content Cell  | Content Cell
Content Cell  | Content Cell

You can align cell contents with syntax like this:

| Left Aligned  | Center Aligned  | Right Aligned |
|:------------- |:---------------:| -------------:|
| col 3 is      | some wordy text |         $1600 |
| col 2 is      | centered        |           $12 |
| zebra stripes | are neat        |            $1 |

The left- and right-most pipes (`|`) are only aesthetic, and can be omitted. The spaces don’t matter, either. Alignment depends solely on `:` marks.

#### <a name="fenced-code-block">Fenced Code Block</a>

This is a fenced code block:

```
print ('Hello world!)'
```

You can also use waves (`~`) instead of back ticks (`` ` ``):

~~~
print('Hello world!')
~~~


You can add an optional language ID at the end of the first line. The language ID will only be used to highlight the code inside if you tick the ***Enable highlighting in code blocks*** option. This is what happens if you enable it:

![Syntax highlighting example](http://d.pr/i/9HM6+)

I support many popular languages as well as some generic syntax descriptions that can be used if your language of choice is not supported. See [relevant sections on the official site](http://macdown.uranusjr.com/features/) for a full list of supported syntaxes.


### Inline Formatting

The following is a list of optional inline markups supported:

Option name         | Markup           | Result if enabled     |
--------------------|------------------|-----------------------|
Intra-word emphasis | So A\*maz\*ing   | So A<em>maz</em>ing   |
Strikethrough       | \~~Much wow\~~   | <del>Much wow</del>   |
Underline [^under]  | \_So doge\_      | <u>So doge</u>        |
Quote [^quote]      | \"Such editor\"  | <q>Such editor</q>    |
Highlight           | \==So good\==    | <mark>So good</mark>  |
Superscript         | hoge\^(fuga)     | hoge<sup>fuga</sup>   |
Autolink            | http://t.co      | <http://t.co>         |
Footnotes           | [\^4] and [\^4]: | [^4] and footnote 4   |

[^4]: You don't have to use a number. Arbitrary things like `[^footy note4]` and `[^footy note4]:` will also work. But they will *render* as numbered footnotes. Also, no need to keep your footnotes in order, I will sort out the order for you so they appear in the same order they were referenced in the text body. You can even keep some footnotes near where you referenced them, and collect others at the bottom of the file in the traditional place for footnotes. 




## <a name="rendering-pane"></a>The Rendering Preference Pane
This is where I keep preferences relating to how I render and style the parsed markdown in the preview window.  
![Rendering preferences pane](http://d.pr/i/rT4d+)

### CSS
You can choose different css files for me to use to render your html. You can even customize or add your own custom css files.

### Syntax Highlighting
You have already seen how I can syntax highlight your fenced code blocks. See the [Fenced Code Block](#fenced-code-block) section if you haven’t! You can also choose different themes for syntax highlighting.

### TeX-like Math Syntax
I can also render TeX-like math syntaxes, if you allow me to.[^math] I can do inline math like this: \\( 1 + 1 \\) or this (in MathML): <math><mn>1</mn><mo>+</mo><mn>1</mn></math>, and block math:

\\[
    A^T_S = B
\\]

or (in MathML)

<math display="block">
    <msubsup><mi>A</mi> <mi>S</mi> <mi>T</mi></msubsup>
    <mo>=</mo>
    <mi>B</mi>
</math>



### Task List Syntax
1. [x] I can render checkbox list syntax
	* [x] I support nesting
	* [x] I support ordered *and* unordered lists
2. [ ] I don't support clicking checkboxes directly in the html window


### Jekyll front-matter
If you like, I can display Jekyll front-matter in a nice table. Just make sure you put the front-matter at the very beginning of the file, and fence it with `---`. For example:

```
---
title: "Macdown is my friend"
date: 2014-06-06 20:00:00
---
```

### Render newline literally
Normally I require you to put two spaces and a newline (aka return) at the end of a line in order to create a line break. If you like, I can render a newline any time you end a line with a newline. However, if you enable this, markdown that looks lovely when I render it might look pretty funky when you let some *other* program render it.





## <a name="general-pane"></a>The General Preferences Pane

This is where I keep preferences related to application behavior.  
![General preferences pane](http://d.pr/i/rvwu+)

The General Preferences Pane allows you to tell me how you want me to behave. For example, do you want me to make sure there is a document open when I launch? You can also tell me if I should constantly update the preview window as you type, or wait for you to hit `command-R` instead. Maybe you prefer your editor window on the right? Or to see the word-count as you type. This is also the place to tell me if you are interested in pre-releases of me, or just want to stick to better-tested official releases.  

## <a name="editor-pane"></a>The Editor Preference Pane
This is where I keep preferences related to the behavior and styling of the editing window.  
![Editor preferences pane](http://d.pr/i/6OL5+)


### Styling

My editor provides syntax highlighting. You can edit the base font and the coloring/sizing theme. I provided some default themes (courtesy of [Mou](http://mouapp.com)’s creator, Chen Luo) if you don’t know where to start.

You can also edit, or even add new themes if you want to! Just click the ***Reveal*** button, and start moving things around. Remember to use the correct file extension (`.styles`), though. I’m picky about that.

I offer auto-completion and other functions to ease your editing experience. If you don’t like it, however, you can turn them off.





## Hack On

That’s about it. Thanks for listening. I’ll be quiet from now on (unless there’s an update about the app—I’ll remind you for that!).

Happy writing!


[^emphasize]: If **Underlines** is turned on, `_this notation_` will render as underlined instead of emphasized 

[^under]: If **Underline** is disabled `_this_` will be rendered as *emphasized* instead of being underlined.

[^quote]: **Quote** replaces literal `"` characters with html `<q>` tags. **Quote** and **Smartypants** are syntactically incompatible. If both are enabled, **Quote** takes precedence. Note that **Quote** is different from *blockquote*, which is part of standard Markdown.

[^math]: Internet connection required.


