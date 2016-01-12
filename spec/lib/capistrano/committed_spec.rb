require 'spec_helper'

module Capistrano
  describe Committed do
    it 'has a version number' do
      expect(Committed::VERSION).not_to be nil
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
