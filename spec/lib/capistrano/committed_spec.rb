require 'spec_helper'

module Capistrano
  describe Committed do
    before(:each) do
      Committed.import_settings(
        branch:            :master,
        user:              nil,
        repo:              nil,
        revision_line:     'Branch %{branch} (at %{sha}) deployed as release %{release} by %{user}',
        github_config:     {},
        revision_limit:    10,
        commit_buffer:     1,
        output_path:       '%s/public/committed.txt',
        issue_match:       '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]',
        issue_postprocess: [],
        issue_url:         'https://example.jira.com/browse/%s',
        deployments:       false,
        deployment_id:     nil
      )
    end

    it 'has a version number' do
      expect(Committed::VERSION).not_to be nil
    end

    describe 'import_settings' do
      let(:settings) { { foo: 'hello', bar: 1234 } }
      let(:more_settings) { { baz: 'goodbye' } }
      let(:final_settings) { { foo: 'hello', bar: 1234, baz: 'goodbye' } }

      it 'imports the settings' do
        expect(Committed.import_settings(settings)).to eq settings
      end

      it 'imports more settings' do
        Committed.import_settings(settings)
        expect(Committed.import_settings(more_settings, true)).to eq final_settings
      end
    end

    describe 'get_settings' do
      let(:branch) { 'foo' }
      let(:branch_nil) { nil }

      it 'returns default when variable is not set' do
        expect(Committed.get_setting(:branch)).to eq :master
      end

      it 'returns default when variable is nil' do
        expect(Committed.get_setting(:branch, branch_nil)).to eq :master
      end

      it 'returns "foo" when variable is set' do
        expect(Committed.get_setting(:branch, branch)).to eq branch
      end
    end

    describe 'revision_search_regex' do
      let(:revision_line) { 'Branch %{branch} (at %{sha}) deployed as release %{release} by %{user}' } # rubocop:disable Style/FormatStringToken
      let(:revision_line_escaped) { 'Branch\ (?<branch>.+)\ \(at\ (?<sha>.+)\)\ deployed\ as\ release\ (?<release>.+)\ by\ (?<user>.+)' }

      it 'fails if revision_line is not a String' do
        expect { Committed.revision_search_regex(1234) }.to raise_error TypeError
      end

      it 'returns Regexp' do
        expect(Committed.revision_search_regex(revision_line)).to be_a Regexp
      end

      it 'returns Regexp with escaped pattern' do
        expect(Committed.revision_search_regex(revision_line).source).to eq revision_line_escaped
      end

      it 'returns Regexp with escaped pattern using defaults' do
        expect(Committed.revision_search_regex.source).to eq revision_line_escaped
      end
    end

    describe 'get_revisions_from_lines' do
      let(:lines) do
        ['Branch master (at 08e0390) deployed as release 20160119003754 by jim',
         'Branch master (at 08e0390) deployed as release 20160119002603 by daniel',
         'Branch master (at 66fcf81) deployed as release 20160118044318 by daniel',
         'Branch master (at e5535c4) deployed as release 20160113003755 by mike',
         'Branch master (at 3b3e45d) deployed as release 20160106034830 by sam']
      end
      let(:search) { Committed.revision_search_regex('Branch %{branch} (at %{sha}) deployed as release %{release} by %{user}') } # rubocop:disable Style/FormatStringToken
      let(:revisions) do
        { next: { release: :next, entries: {} },
          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
          '20160118044318' => { branch: 'master', sha: '66fcf81', release: '20160118044318', user: 'daniel', entries: {} },
          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
          previous: { release: :previous, entries: {} } }
      end
      let(:revisions_to_limit) do
        { next: { release: :next, entries: {} },
          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
          previous: { release: :previous, entries: {} } }
      end
      let(:lines_with_branches) do
        ['Branch master (at 08e0390) deployed as release 20160119003754 by jim',
         'Branch other (at 08e0390) deployed as release 20160119002603 by daniel',
         'Branch other (at 66fcf81) deployed as release 20160118044318 by daniel',
         'Branch master (at e5535c4) deployed as release 20160113003755 by mike',
         'Branch master (at 3b3e45d) deployed as release 20160106034830 by sam']
      end
      let(:revisions_in_branch) do
        { next: { release: :next, entries: {} },
          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
          previous: { release: :previous, entries: {} } }
      end
      let(:lines_with_rollback) do
        ['Branch master (at 5a4f743) deployed as release 20160121001342 by cathy',
         'Branch master (at 66fcf81) deployed as release 20160119003754 by jim',
         'daniel rolled back to release 20160113003755',
         'Branch master (at 08e0390) deployed as release 20160119002603 by daniel',
         'Branch master (at e5535c4) deployed as release 20160113003755 by mike',
         'Branch master (at 3b3e45d) deployed as release 20160106034830 by sam']
      end
      let(:revisions_with_rollback) do
        { next: { release: :next, entries: {} },
          '20160121001342' => { branch: 'master', sha: '5a4f743', release: '20160121001342', user: 'cathy', entries: {} },
          '20160119003754' => { branch: 'master', sha: '66fcf81', release: '20160119003754', user: 'jim', entries: {} },
          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
          previous: { release: :previous, entries: {} } }
      end

      it 'fails if lines is not an Array' do
        expect { Committed.get_revisions_from_lines(nil, search, 'master', 10) }.to raise_error TypeError
      end

      it 'fails if a lines item is not a String' do
        expect { Committed.get_revisions_from_lines(['one', nil, 'three'], search, 'master', 10) }.to raise_error TypeError
      end

      it 'fails if search is not a Regexp' do
        expect { Committed.get_revisions_from_lines(lines, 1234, 'master', 10) }.to raise_error TypeError
      end

      it 'fails if branch is not a Symbol or a String' do
        expect { Committed.get_revisions_from_lines(lines, search, 1234, 10) }.to raise_error TypeError
      end

      it 'fails if limit is not an Integer' do
        expect { Committed.get_revisions_from_lines(lines, search, 'master', 'foo') }.to raise_error TypeError
      end

      it 'returns lines' do
        expect(Committed.get_revisions_from_lines(lines, search, 'master', 10)).to eq revisions
      end

      it 'returns lines using defaults' do
        expect(Committed.get_revisions_from_lines(lines)).to eq revisions
      end

      it 'returns lines up to limit' do
        expect(Committed.get_revisions_from_lines(lines, search, 'master', 2)).to eq revisions_to_limit
      end

      it 'returns lines in given branch' do
        expect(Committed.get_revisions_from_lines(lines_with_branches, search, 'master', 10)).to eq revisions_in_branch
      end

      it 'returns lines and ignores rollbacks' do
        expect(Committed.get_revisions_from_lines(lines_with_rollback, search, 'master', 10)).to eq revisions_with_rollback
      end
    end

    describe 'add_dates_to_revisions' do
      let(:revisions) do
        { next: { release: :next, entries: {} },
          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
          '20160118044318' => { branch: 'master', sha: '66fcf81', release: '20160118044318', user: 'daniel', entries: {} },
          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
          previous: { release: :previous, entries: {} } }
      end
      let(:github) { Committed::GithubApi.new }
      let(:git_user) { 'username' }
      let(:git_repo) { 'repository' }

      it 'fails if revisions is not a Hash' do
        expect { Committed.add_dates_to_revisions(nil, github, git_user, git_repo) }.to raise_error TypeError
      end

      it 'fails if github is not a GitHubApi object' do
        expect { Committed.add_dates_to_revisions(revisions, nil, git_user, git_repo) }.to raise_error TypeError
      end

      it 'fails if git_user is not a String' do
        expect { Committed.add_dates_to_revisions(revisions, github, nil, git_repo) }.to raise_error TypeError
      end

      it 'fails if git_repo is not a String' do
        expect { Committed.add_dates_to_revisions(revisions, github, git_user, nil) }.to raise_error TypeError
      end
    end

    describe 'get_earliest_date_from_revisions' do
      let(:revisions) do
        { next: { release: :next, entries: {} },
          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {}, date: '2015-08-11T05:00:00+11:00' },
          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {}, date: '2015-08-11T04:00:00+11:00' },
          '20160118044318' => { branch: 'master', sha: '66fcf81', release: '20160118044318', user: 'daniel', entries: {}, date: '2015-08-11T03:00:00+11:00' },
          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {}, date: '2015-08-11T02:00:00+11:00' },
          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {}, date: '2015-08-11T01:00:00+11:00' },
          previous: { release: :previous, entries: {} } }
      end

      it 'fails if revisions is not a Hash' do
        expect { Committed.get_earliest_date_from_revisions(nil) }.to raise_error TypeError
      end

      it 'returns nil if revisions is empty' do
        expect(Committed.get_earliest_date_from_revisions({})).to eq nil
      end

      it 'returns earliest date' do
        expect(Committed.get_earliest_date_from_revisions(revisions)).to eq Time.parse('2015-08-11T01:00:00+11:00')
      end
    end

    describe 'days_to_seconds' do
      let(:days_integer) { 2 }
      let(:days_float) { 2.5 }
      let(:days_string) { 'two' }

      it 'fails if revisions is not a Numeric (nil)' do
        expect { Committed.days_to_seconds(nil) }.to raise_error TypeError
      end

      it 'fails if revisions is not a Numeric (String)' do
        expect { Committed.days_to_seconds(days_string) }.to raise_error TypeError
      end

      it 'returns 172800 when days is 2' do
        expect(Committed.days_to_seconds(days_integer)).to eq 172_800
      end

      it 'returns 216000 when days is 2.5' do
        expect(Committed.days_to_seconds(days_float)).to eq 216_000
      end
    end

    describe 'add_buffer_to_time' do
      let(:time) { Time.parse('2010-10-10 10:00:00 +0000') }
      let(:days_integer) { 2 }
      let(:days_float) { 2.5 }

      it 'fails if time is not a Time' do
        expect { Committed.add_buffer_to_time(nil, days_integer) }.to raise_error TypeError
      end

      it 'fails if buffer_in_days is not a Numeric (String)' do
        expect { Committed.add_buffer_to_time(time, 'foo') }.to raise_error TypeError
      end

      it 'returns 2010-10-08T10:00:00+00:00 when buffer_in_days is 2' do
        expect(Committed.add_buffer_to_time(time, days_integer)).to eq '2010-10-08T10:00:00+00:00'
      end

      it 'returns 2010-10-07T22:00:00+00:00 when buffer_in_days is 2.5' do
        expect(Committed.add_buffer_to_time(time, days_float)).to eq '2010-10-07T22:00:00+00:00'
      end

      it 'returns 2010-10-09T10:00:00+00:00 using defaults' do
        expect(Committed.add_buffer_to_time(time)).to eq '2010-10-09T10:00:00+00:00'
      end
    end

    describe 'get_issue_urls' do
      let(:issue_match) { '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]' }
      let(:issue_postprocess) { [] }
      let(:issue_postprocess_with_nil) { [:foo, :bar, nil] }
      let(:issue_postprocess_with_upcase) { [:upcase] }
      let(:issue_url) { 'https://example.jira.com/browse/%s' }
      let(:issueless_message) { 'Foo bar lulz' }
      let(:one_issue) { ['https://example.jira.com/browse/PROJECT-101'] }
      let(:one_issue_message) { 'Foo bar [PROJECT-101] lulz' }
      let(:one_issue_message_lowercase) { 'Foo bar [project-101] lulz' }
      let(:two_issues) do
        ['https://example.jira.com/browse/PROJECT-101',
         'https://example.jira.com/browse/PROJECT-102']
      end
      let(:two_issues_message) { 'Foo bar [PROJECT-101] [PROJECT-102] lulz' }
      let(:two_adjoining_issues_message) { 'Foo bar [PROJECT-101][PROJECT-102] lulz' }
      let(:two_issues_over_two_lines_message) { "Foo bar [PROJECT-101] lulz\n[PROJECT-102] also" }
      let(:deduplicated_issue) { ['https://example.jira.com/browse/PROJECT-103'] }
      let(:deduplicated_issue_message) { 'Foo [PROJECT-103] bar [PROJECT-103] lah!' }

      it 'fails if issue_match is not a String or Regexp' do
        expect { Committed.get_issue_urls(issueless_message, 1234, issue_postprocess, issue_url) }.to raise_error TypeError
      end

      it 'fails if issue_postprocess is not an Array' do
        expect { Committed.get_issue_urls(issueless_message, issue_match, 1234, issue_url) }.to raise_error TypeError
      end

      it 'fails if a issue_postprocess item is not a Symbol' do
        expect { Committed.get_issue_urls(issueless_message, issue_match, issue_postprocess_with_nil, issue_url) }.to raise_error TypeError
      end

      it 'fails if issue_url is not a String' do
        expect { Committed.get_issue_urls(issueless_message, issue_match, issue_postprocess, 1234) }.to raise_error TypeError
      end

      it 'fails if message is not a String' do
        expect { Committed.get_issue_urls(nil, issue_match, issue_postprocess, issue_url) }.to raise_error TypeError
      end

      it 'returns empty array if there are no issues' do
        expect(Committed.get_issue_urls(issueless_message, issue_match, issue_postprocess, issue_url)).to match_array []
      end

      it 'returns array with one match if there is one issue' do
        expect(Committed.get_issue_urls(one_issue_message, issue_match, issue_postprocess, issue_url)).to match_array one_issue
      end

      it 'returns array with one match uppercased if there is one issue and issue_postprocess is :upcase' do
        expect(Committed.get_issue_urls(one_issue_message_lowercase, issue_match, issue_postprocess_with_upcase, issue_url)).to match_array one_issue
      end

      it 'returns array with two matches if there are two issues' do
        expect(Committed.get_issue_urls(two_issues_message, issue_match, issue_postprocess, issue_url)).to match_array two_issues
      end

      it 'returns array with two matches if there are two issues using defaults' do
        expect(Committed.get_issue_urls(two_issues_message)).to match_array two_issues
      end

      it 'returns array with two matches if there are two adjoining issues' do
        expect(Committed.get_issue_urls(two_adjoining_issues_message, issue_match, issue_postprocess, issue_url)).to match_array two_issues
      end

      it 'returns array with two matches if there are two issues over two lines' do
        expect(Committed.get_issue_urls(two_issues_over_two_lines_message, issue_match, issue_postprocess, issue_url)).to match_array two_issues
      end

      it 'returns array with one match if there are duplicate issues' do
        expect(Committed.get_issue_urls(deduplicated_issue_message, issue_match, issue_postprocess, issue_url)).to match_array deduplicated_issue
      end
    end
  end
end
