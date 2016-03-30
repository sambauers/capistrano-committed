require 'spec_helper'

module Capistrano
  describe Committed do
    it 'has a version number' do
      expect(Committed::VERSION).not_to be nil
    end

    describe 'revision_search_regex' do
      let(:revision_line) { 'Branch %{branch} (at %{sha}) deployed as release %{release} by %{user}' }
      let(:revision_line_escaped) { 'Branch\ (?<branch>.+)\ \(at\ (?<sha>.+)\)\ deployed\ as\ release\ (?<release>.+)\ by\ (?<user>.+)' }

      it 'fails if revision_line is not a String' do
        expect{ Committed.revision_search_regex(nil) }.to raise_error TypeError
      end

      it 'returns Regexp' do
        expect(Committed.revision_search_regex(revision_line)).to be_a Regexp
      end

      it 'returns Regexp with escaped pattern' do
        expect(Committed.revision_search_regex(revision_line).source).to eq revision_line_escaped
      end
    end

    describe 'get_revisions_from_lines' do
      let(:lines) { ['Branch master (at 08e0390) deployed as release 20160119003754 by jim',
                     'Branch master (at 08e0390) deployed as release 20160119002603 by daniel',
                     'Branch master (at 66fcf81) deployed as release 20160118044318 by daniel',
                     'Branch master (at e5535c4) deployed as release 20160113003755 by mike',
                     'Branch master (at 3b3e45d) deployed as release 20160106034830 by sam'] }
      let(:search) { Committed.revision_search_regex('Branch %{branch} (at %{sha}) deployed as release %{release} by %{user}') }
      let(:revisions) { { next: { entries: {} },
                          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
                          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
                          '20160118044318' => { branch: 'master', sha: '66fcf81', release: '20160118044318', user: 'daniel', entries: {} },
                          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
                          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
                          previous: { entries: {} }
      } }
      let(:revisions_to_limit) { { next: { entries: {} },
                          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
                          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
                          previous: { entries: {} }
      } }
      let(:lines_with_branches) { ['Branch master (at 08e0390) deployed as release 20160119003754 by jim',
                                   'Branch other (at 08e0390) deployed as release 20160119002603 by daniel',
                                   'Branch other (at 66fcf81) deployed as release 20160118044318 by daniel',
                                   'Branch master (at e5535c4) deployed as release 20160113003755 by mike',
                                   'Branch master (at 3b3e45d) deployed as release 20160106034830 by sam'] }
      let(:revisions_in_branch) { { next: { entries: {} },
                          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
                          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
                          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
                          previous: { entries: {} }
      } }
      let(:lines_with_rollback) { [
                                   'Branch master (at 5a4f743) deployed as release 20160121001342 by cathy',
                                   'Branch master (at 66fcf81) deployed as release 20160119003754 by jim',
                                   'daniel rolled back to release 20160113003755',
                                   'Branch master (at 08e0390) deployed as release 20160119002603 by daniel',
                                   'Branch master (at e5535c4) deployed as release 20160113003755 by mike',
                                   'Branch master (at 3b3e45d) deployed as release 20160106034830 by sam'] }
      let(:revisions_with_rollback) { { next: { entries: {} },
                                        '20160121001342' => { branch: 'master', sha: '5a4f743', release: '20160121001342', user: 'cathy', entries: {} },
                                        '20160119003754' => { branch: 'master', sha: '66fcf81', release: '20160119003754', user: 'jim', entries: {} },
                                        '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
                                        '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
                                        '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
                                        previous: { entries: {} }
      } }

      it 'fails if lines is not an Array' do
        expect{ Committed.get_revisions_from_lines(nil, search, 'master', 10) }.to raise_error TypeError
      end

      it 'fails if a lines item is not a String' do
        expect{ Committed.get_revisions_from_lines(['one', nil, 'three'], search, 'master', 10) }.to raise_error TypeError
      end

      it 'fails if search is not a Regexp' do
        expect{ Committed.get_revisions_from_lines(lines, nil, 'master', 10) }.to raise_error TypeError
      end

      it 'fails if branch is not a String' do
        expect{ Committed.get_revisions_from_lines(lines, search, nil, 10) }.to raise_error TypeError
      end

      it 'fails if limit is not an Integer' do
        expect{ Committed.get_revisions_from_lines(lines, search, 'master', nil) }.to raise_error TypeError
      end

      it 'returns lines' do
        expect(Committed.get_revisions_from_lines(lines, search, 'master', 10)).to eq revisions
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
      let(:revisions) { { next: { entries: {} },
                          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {} },
                          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {} },
                          '20160118044318' => { branch: 'master', sha: '66fcf81', release: '20160118044318', user: 'daniel', entries: {} },
                          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {} },
                          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {} },
                          previous: { entries: {} }
      } }
      let(:github) { Committed::GithubApi.new() }
      let(:git_user) { 'username' }
      let(:git_repo) { 'repository' }

      it 'fails if revisions is not a Hash' do
        expect{ Committed.add_dates_to_revisions(nil, github, git_user, git_repo) }.to raise_error TypeError
      end

      it 'fails if github is not a GitHubApi object' do
        expect{ Committed.add_dates_to_revisions(revisions, nil, git_user, git_repo) }.to raise_error TypeError
      end

      it 'fails if git_user is not a String' do
        expect{ Committed.add_dates_to_revisions(revisions, github, nil, git_repo) }.to raise_error TypeError
      end

      it 'fails if git_repo is not a String' do
        expect{ Committed.add_dates_to_revisions(revisions, github, git_user, nil) }.to raise_error TypeError
      end
    end

    describe 'get_earliest_date_from_revisions' do
      let(:revisions) { { next: { entries: {} },
                          '20160119003754' => { branch: 'master', sha: '08e0390', release: '20160119003754', user: 'jim', entries: {}, date: '2015-08-11T05:00:00+11:00' },
                          '20160119002603' => { branch: 'master', sha: '08e0390', release: '20160119002603', user: 'daniel', entries: {}, date: '2015-08-11T04:00:00+11:00' },
                          '20160118044318' => { branch: 'master', sha: '66fcf81', release: '20160118044318', user: 'daniel', entries: {}, date: '2015-08-11T03:00:00+11:00' },
                          '20160113003755' => { branch: 'master', sha: 'e5535c4', release: '20160113003755', user: 'mike', entries: {}, date: '2015-08-11T02:00:00+11:00' },
                          '20160106034830' => { branch: 'master', sha: '3b3e45d', release: '20160106034830', user: 'sam', entries: {}, date: '2015-08-11T01:00:00+11:00' },
                          previous: { entries: {} }
      } }

      it 'fails if revisions is not a Hash' do
        expect{ Committed.get_earliest_date_from_revisions(nil) }.to raise_error TypeError
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
        expect{ Committed.days_to_seconds(nil) }.to raise_error TypeError
      end

      it 'fails if revisions is not a Numeric (String)' do
        expect{ Committed.days_to_seconds(days_string) }.to raise_error TypeError
      end

      it 'returns 172800 when days is 2' do
        expect(Committed.days_to_seconds(days_integer)).to eq 172800
      end

      it 'returns 216000 when days is 2.5' do
        expect(Committed.days_to_seconds(days_float)).to eq 216000
      end
    end

    describe 'add_buffer_to_time' do
      let(:time) { Time.parse('2010-10-10 10:00:00 +0000') }
      let(:days_integer) { 2 }
      let(:days_float) { 2.5 }
      let(:days_string) { 'two' }

      it 'fails if time is not a Time' do
        expect{ Committed.add_buffer_to_time(nil, days_integer) }.to raise_error TypeError
      end

      it 'fails if buffer_in_days is not a Numeric (nil)' do
        expect{ Committed.add_buffer_to_time(time, nil) }.to raise_error TypeError
      end

      it 'fails if buffer_in_days is not a Numeric (String)' do
        expect{ Committed.add_buffer_to_time(time, days_string) }.to raise_error TypeError
      end

      it 'returns 2010-10-08T10:00:00+00:00 when buffer_in_days is 2' do
        expect(Committed.add_buffer_to_time(time, days_integer)).to eq '2010-10-08T10:00:00+00:00'
      end

      it 'returns 2010-10-07T22:00:00+00:00 when buffer_in_days is 2.5' do
        expect(Committed.add_buffer_to_time(time, days_float)).to eq '2010-10-07T22:00:00+00:00'
      end
    end



    describe 'get_issue_urls' do
      let(:issue_pattern) { '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]' }
      let(:postprocess) { [] }
      let(:postprocess_with_nil) { [:foo, :bar, nil] }
      let(:postprocess_with_upcase) { [:upcase] }
      let(:url_pattern) { 'https://example.jira.com/browse/%s' }
      let(:issueless_message) { 'Foo bar lulz' }
      let(:one_issue) { ['https://example.jira.com/browse/PROJECT-101'] }
      let(:one_issue_message) { 'Foo bar [PROJECT-101] lulz' }
      let(:one_issue_message_lowercase) { 'Foo bar [project-101] lulz' }
      let(:two_issues) { ['https://example.jira.com/browse/PROJECT-101',
                          'https://example.jira.com/browse/PROJECT-102'] }
      let(:two_issues_message) { 'Foo bar [PROJECT-101] [PROJECT-102] lulz' }
      let(:two_adjoining_issues_message) { 'Foo bar [PROJECT-101][PROJECT-102] lulz' }
      let(:two_issues_over_two_lines_message) { "Foo bar [PROJECT-101] lulz\n[PROJECT-102] also" }

      it 'fails if issue_pattern is not a String or Regexp' do
        expect{ Committed.get_issue_urls(nil, postprocess, url_pattern, issueless_message) }.to raise_error TypeError
      end

      it 'fails if postprocess is not an Array' do
        expect{ Committed.get_issue_urls(issue_pattern, nil, url_pattern, issueless_message) }.to raise_error TypeError
      end

      it 'fails if a postprocess item is not a Symbol' do
        expect{ Committed.get_issue_urls(issue_pattern, postprocess_with_nil, url_pattern, issueless_message) }.to raise_error TypeError
      end

      it 'fails if url_pattern is not a String' do
        expect{ Committed.get_issue_urls(issue_pattern, postprocess, nil, issueless_message) }.to raise_error TypeError
      end

      it 'fails if message is not a String' do
        expect{ Committed.get_issue_urls(issue_pattern, postprocess, url_pattern, nil) }.to raise_error TypeError
      end

      it 'returns empty array if there are no issues' do
        expect(Committed.get_issue_urls(issue_pattern, postprocess, url_pattern, issueless_message)).to match_array []
      end

      it 'returns array with one match if there is one issue' do
        expect(Committed.get_issue_urls(issue_pattern, postprocess, url_pattern, one_issue_message)).to match_array one_issue
      end

      it 'returns array with one match uppercased if there is one issue and postprocess is :upcase' do
        expect(Committed.get_issue_urls(issue_pattern, postprocess_with_upcase, url_pattern, one_issue_message_lowercase)).to match_array one_issue
      end

      it 'returns array with two matches if there are two issues' do
        expect(Committed.get_issue_urls(issue_pattern, postprocess, url_pattern, two_issues_message)).to match_array two_issues
      end

      it 'returns array with two matches if there are two adjoining issues' do
        expect(Committed.get_issue_urls(issue_pattern, postprocess, url_pattern, two_adjoining_issues_message)).to match_array two_issues
      end

      it 'returns array with two matches if there are two issues over two lines' do
        expect(Committed.get_issue_urls(issue_pattern, postprocess, url_pattern, two_issues_over_two_lines_message)).to match_array two_issues
      end
    end

    describe 'format_issue_urls' do
      it 'returns empty array if no urls' do
        expect(Committed.format_issue_urls(nil)).to match_array []
        expect(Committed.format_issue_urls('')).to match_array []
        expect(Committed.format_issue_urls([])).to match_array []
      end

      let(:urls) { ['https://example.jira.com/browse/PROJECT-123',
                    'https://example.jira.com/browse/PROJECT-124',
                    'https://example.jira.com/browse/PROJECT-128'] }
      let(:output) { [format('   %s', t('committed.output.issue_links')),
                      '   - https://example.jira.com/browse/PROJECT-123',
                      '   - https://example.jira.com/browse/PROJECT-124',
                      '   - https://example.jira.com/browse/PROJECT-128',
                      ''] }
      let(:pad) { '   |' }
      let(:padded_output) { [format('   |   %s', t('committed.output.issue_links')),
                             '   |   - https://example.jira.com/browse/PROJECT-123',
                             '   |   - https://example.jira.com/browse/PROJECT-124',
                             '   |   - https://example.jira.com/browse/PROJECT-128',
                             '   |'] }

      it 'returns array of formatted text' do
        expect(Committed.format_issue_urls(urls)).to match_array output
      end

      it 'returns array of formatted text with padding' do
        expect(Committed.format_issue_urls(urls, pad)).to match_array padded_output
      end
    end
  end
end
