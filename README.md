# Ralf

- for each bucket:
  - √ sync the logfiles from the last N days onto the local filesystem
  - √ load every logfile in memory and merge it in a hashtable
  - √ remove ignored lines
  - √ sort it by timestamp
  - save and optionally split it in a directory (ex. :year/:month/:day) as given in the options
  - merge the last N days into combined ordered logs

## Installation

Add this line to your application's Gemfile:

    gem 'ralf'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ralf

## Usage

TODO: Write usage instructions here

## Version history

Release 1.1.1 [2013-02-11 13:14]

* Update gemspec
* extract the translator in it's own class
* add option to recalculate the '206 Partial Content' issue on S3
	(see https://forums.aws.amazon.com/thread.jspa?threadID=54214 for more details)

Release 1.1.0 [2011-05-08]

* Switched to Fileutils for 1.9 compatibility

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
