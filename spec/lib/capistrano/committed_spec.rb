require 'spec_helper'

describe Capistrano::Committed do
  it 'has a version number' do
    expect(Capistrano::Committed::VERSION).not_to be nil
  end

  describe 'get_issue_urls' do
    let(:issue_pattern) { '\[\s?([A-Z0-9]+\-[0-9]+)\s?\]' }
    let(:url_pattern) { 'https://example.jira.com/browse/%s' }
    let(:issueless_message) { 'Foo bar lulz' }
    let(:one_issue) { ['https://example.jira.com/browse/PROJECT-101'] }
    let(:one_issue_message) { 'Foo bar [PROJECT-101] lulz' }
    let(:two_issues) { ['https://example.jira.com/browse/PROJECT-101',
                        'https://example.jira.com/browse/PROJECT-102'] }
    let(:two_issues_message) { 'Foo bar [PROJECT-101] [PROJECT-102] lulz' }
    let(:two_adjoining_issues_message) { 'Foo bar [PROJECT-101][PROJECT-102] lulz' }
    let(:two_issues_over_two_lines_message) { "Foo bar [PROJECT-101] lulz\n[PROJECT-102] also" }

    it 'fails if issue_pattern is not a String or Regexp' do
      expect{ Capistrano::Committed.get_issue_urls(nil, nil, nil) }.to raise_error TypeError
    end

    it 'fails if url_pattern is not a String' do
      expect{ Capistrano::Committed.get_issue_urls(issue_pattern, nil, nil) }.to raise_error TypeError
    end

    it 'fails if message is not a String' do
      expect{ Capistrano::Committed.get_issue_urls(issue_pattern, url_pattern, nil) }.to raise_error TypeError
    end

    it 'returns empty array if there are no issues' do
      expect(Capistrano::Committed.get_issue_urls(issue_pattern, url_pattern, issueless_message)).to match_array []
    end

    it 'returns array with one match if there is one issue' do
      expect(Capistrano::Committed.get_issue_urls(issue_pattern, url_pattern, one_issue_message)).to match_array one_issue
    end

    it 'returns array with two matches if there are two issues' do
      expect(Capistrano::Committed.get_issue_urls(issue_pattern, url_pattern, two_issues_message)).to match_array two_issues
    end

    it 'returns array with two matches if there are two adjoining issues' do
      expect(Capistrano::Committed.get_issue_urls(issue_pattern, url_pattern, two_adjoining_issues_message)).to match_array two_issues
    end

    it 'returns array with two matches if there are two issues over two lines' do
      expect(Capistrano::Committed.get_issue_urls(issue_pattern, url_pattern, two_issues_over_two_lines_message)).to match_array two_issues
    end
  end

  describe 'format_issue_urls' do
    it 'returns empty array if no urls' do
      expect(Capistrano::Committed.format_issue_urls(nil)).to match_array []
      expect(Capistrano::Committed.format_issue_urls('')).to match_array []
      expect(Capistrano::Committed.format_issue_urls([])).to match_array []
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
      expect(Capistrano::Committed.format_issue_urls(urls)).to match_array output
    end

    it 'returns array of formatted text with padding' do
      expect(Capistrano::Committed.format_issue_urls(urls, pad)).to match_array padded_output
    end
  end
end
