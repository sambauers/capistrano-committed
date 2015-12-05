<div align="center">
  <a href="https://github.com/sambauers/capistrano-committed"><img width="136" src="https://github.com/sambauers/capistrano-committed/raw/master/icons/capricorn.png" alt="Capistrano Committed logo" /></a>
</div>

# Capistrano Committed

[![Gem Version](https://badge.fury.io/rb/capistrano-committed.svg)](https://badge.fury.io/rb/capistrano-committed)
[![Dependency Status](https://gemnasium.com/sambauers/capistrano-committed.svg)](https://gemnasium.com/sambauers/capistrano-committed)

Capistrano Committed is an extension to Capistrano 3 which helps to determine what you are about to deploy.

It creates a report, which lets you know which GitHub commits and pull requests are not yet deployed to the target stage (server).

It does this by:

1. reading the revision log on the server;
2. getting all the commits on the specified branch from GitHub (via API);
3. looking through those commits and finding all the pull requests;
4. getting the info and commits in each pull request;
5. pumping all that data into a report;
6. uploading that report to the server.

At the moment this only works with GitHub repositories, if you have another Git service you would like it to support then please submit a pull request.

## Installation

Add this line to your application's Gemfile (usually in the `:development` group):

```ruby
gem 'capistrano-committed'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install capistrano-committed

In your projects Capfile add this line:

```ruby
require 'capistrano/committed'
```

## Usage

In `config/deploy.rb` (in Rails) you need to set at least these options:

```ruby
# This is the GitHub user or organisation for the repository
set :committed_user, nil
set :committed_repo, nil
```

You will usually need to set the `:committed_github_config` option in order to authenticate, this setting is a hash of options which are passed directly to the [GitHub API gem](https://github.com/peter-murach/github). The full list of GitHub API configuration option are in the [GitHub API gem read me file](https://github.com/peter-murach/github#2-configuration).

Example of personal access token usage:

```ruby
set :committed_github_config, {
  :oauth_token => '65741acbd6473216583421cdef'
}
```

Example of basic auth usage:

```ruby
set :committed_github_config, {
  :basic_auth => 'my-username:my-p455w0rd'
}
```

The following settings are optional, the default values are shown here:

```ruby
# This describes the line that we are looking for and matching against to get
# revision details from the revision log. Grabbing this from Capistrano locales
# by default.
set :committed_revision_line, I18n.t('capistrano.revision_log_message')

# The config passed to the GitHub API gem - will usually contain auth details.
set :committed_github_config, {}

# How far back in the revision log we should look
set :committed_revision_limit, 10

# How many days beyond the last revision we fetch should we look for commits
set :committed_commit_buffer, 1

# Where to upload the report - '%s' is replaced with `current_path` if present.
# `nil` will stop the report from uploading at all, and print to STDOUT instead.
set :committed_output_path, '%s/public/committed.txt'

# This is a regexp pattern that describes issue numbers in commit titles and
# descriptions. This example matches JIRA numbers enclosed in square braces -
# e.g. "[ABC-12345]" with the part inside the braces being captured "ABC-12345".
# Setting this to `nil` will disable issue matching altogether. Note that this
# setting should specify a string, not a Ruby Regexp object. Specifying a Regexp
# object might work, but it is not tested.
set :committed_issue_match, '\[\s?([A-Z0-9]+\-[0-9]+)\s?\]'

# This is the URL structure for issues which are found. The default is for a
# JIRA on Demand instance - e.g. https://example.jira.com/browse/ABC-12345
# "%s" will be replaced with the issue number. Setting this to `nil` will also
# disable issue matching altogether.
set :committed_issue_url, 'https://example.jira.com/browse/%s'
```

Once your required settings are all in place, you can generate a report by running:

```shell
$ cap <stage> committed:generate
```

## What's with the unicorn?

<div align="center">
  <a href="https://github.com/sambauers/capistrano-committed"><img width="640" src="https://github.com/sambauers/capistrano-committed/raw/master/icons/capricorn_equation.png" alt="Capistrano + GitHub API gem = Capistrano Committed gem" /></a>
</div>

* [Capistrano](http://capistranorb.com)
* [GitHub API gem](https://github.com/peter-murach/github)


