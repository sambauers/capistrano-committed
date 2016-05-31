require 'spec_helper'

module Capistrano
  module Committed
    describe Output do
      let(:object) { described_class }
      subject(:output) { object.new }

      context 'initialisation' do
        after(:each) {
          output.get_output_template_path
        }

        describe 'get_output_path' do
          let(:file) { 'output_foo.mustache' }

          it 'returns a string containing the file' do
            expect(output.get_output_path(file)).to match(/\/lib\/capistrano\/committed\/output\/output\_foo\.mustache$/)
          end
        end

        describe 'get_output_template_path' do
          it 'returns a string containing the txt template path' do
            expect(output.get_output_template_path).to match(/\/lib\/capistrano\/committed\/output\/output\_txt\.mustache$/)
          end

          it 'returns a string containing the html template path' do
            expect(output.get_output_template_path('html')).to match(/\/lib\/capistrano\/committed\/output\/output\_html\.mustache$/)
          end
        end

        describe 'template_format' do
          it 'returns the new template_format when set' do
            output.get_output_template_path('html')
            expect(output.template_format).to eq 'html'
          end

          it 'returns the old template_format when not set' do
            output.get_output_template_path('html', false)
            expect(output.template_format).to eq 'txt'
          end
        end
      end

      context 'template helpers' do
        describe 'release_header' do
          let(:date) { '2016-05-09T00:04:34Z' }

          before {
            output.context.current[:date] = date
          }

          it 'returns next release header' do
            output.context.current[:release] = :next
            expect(output.release_header).to eq 'Next release'
          end

          it 'returns previous release header' do
            output.context.current[:release] = :previous
            expect(output.release_header).to eq format('Commits before %s are omitted from the report   ¯\_(ツ)_/¯',
                                                       date)
          end

          it 'returns the formatted release header' do
            output.context.current[:release] = '20160525010106'
            output.context.current[:sha] = 'a2c4e6g'
            expect(output.release_header).to eq format('Release on 2016-05-25T01:01:06+00:00 from commit a2c4e6g at %s',
                                                       date)
          end
        end

        describe 'items' do
        end

        describe 'item_title' do
          let(:sha)     { '4282cbdea4368f0f074ddacd9baf123036ad36e3' }
          let(:number)  { 45 }

          before(:each) do
            output.context.current[:info] = { sha: sha, number: number }
          end

          it 'returns the formatted commit title' do
            output.context.current[:type] = :commit
            expect(output.item_title).to eq format('Commit %s', sha)
          end

          it 'returns the formatted pull request title' do
            output.context.current[:type] = :pull_request
            expect(output.item_title).to eq format('Pull Request #%s', number)
          end
        end

        context 'item subtitle methods' do
          let(:title) { 'Fixed the thing, made it good' }

          before do
            output.context.current[:type] = :pull_request
            output.context.current[:info] = { title: title }
          end

          describe 'item_subtitle' do
            it 'returns the title' do
              expect(output.item_subtitle).to eq title
            end
          end

          describe 'has_item_subtitle' do
            it 'returns true when there is a title' do
              expect(output.has_item_subtitle).to eq true
            end

            it 'returns false when there is not a title' do
              output.context.current[:info][:title] = nil
              expect(output.has_item_subtitle).to eq false
            end
          end
        end

        context 'item lines methods' do
          let(:message) { "This is the first line\r\nThis is the second line" }
          let(:lines) { ['This is the first line', 'This is the second line'] }

          before(:each) do
            output.context.current[:type] = :commit
            output.context.current[:info] = { commit: { message: message } }
          end

          describe 'item_lines' do
            it 'returns an array of lines from the commit' do
              expect(output.item_lines).to eq lines
            end

            it 'returns an array of lines from the pull request' do
              output.context.current[:type] = :pull_request
              output.context.current[:info] = { body: message }
              expect(output.item_lines).to eq lines
            end
          end

          describe 'has_item_lines' do
            it 'returns true when there are item lines' do
              expect(output.has_item_lines).to eq true
            end

            it 'returns false when there are not item lines' do
              output.context.current[:info][:commit][:message] = nil
              expect(output.has_item_lines).to eq false
            end
          end
        end

        context 'issue links methods' do
          let(:message) { "This is the first [PROJECT-123]\r\nThis is the second [PROJECT-456]" }
          let(:links) { ['https://example.jira.com/browse/PROJECT-123', 'https://example.jira.com/browse/PROJECT-456'] }

          before(:each) do
            output.context.current[:type] = :commit
            output.context.current[:info] = { commit: { message: message } }
            ::Capistrano::Committed.import_settings({
              issue_match: '\[\s?([a-zA-Z0-9]+\-[0-9]+)\s?\]',
              issue_postprocess: [],
              issue_url: 'https://example.jira.com/browse/%s'
            })
          end

          describe 'issue_links' do
            it 'returns an array of links from the commit' do
              expect(output.issue_links).to eq links
            end

            it 'returns an array of links from the pull request' do
              output.context.current[:type] = :pull_request
              output.context.current[:info] = { title: 'Test', body: message }
              expect(output.issue_links).to eq links
            end
          end

          describe 'has_issue_links' do
            it 'returns true when there are issue links' do
              expect(output.has_issue_links).to eq true
            end

            it 'returns false when there are not issue links' do
              output.context.current[:info][:commit][:message] = 'Test'
              expect(output.has_issue_links).to eq false
            end
          end
        end

        describe 'issue_link' do
          let(:url) { 'https://example.org/test' }

          it 'returns the html formatted issue link' do
            output.get_output_template_path('html')
            output.context.push url
            expect(output.issue_link).to eq format('<a href="%s">%s</a>', url, url)
          end

          it 'returns the txt issue link' do
            output.get_output_template_path('txt')
            output.context.push url
            expect(output.issue_link).to eq url
          end
        end

        describe 'item_created_on' do
          let(:date) { '2016-05-09T00:04:34Z' }

          it 'returns the formatted commit creation date' do
            output.context.current[:type] = :commit
            output.context.current[:info] = { commit: { committer: { date: date } } }
            expect(output.item_created_on).to eq format('Committed on: %s',
                                                        date)
          end

          it 'returns the formatted pull request merge date' do
            output.context.current[:type] = :pull_request
            output.context.current[:info] = { merged_at: date }
            expect(output.item_created_on).to eq format('Merged on: %s',
                                                        date)
          end
        end

        describe 'item_created_by' do
          let(:login) { 'username' }

          it 'returns the formatted committer' do
            output.context.current[:type] = :commit
            output.context.current[:info] = { committer: { login: login } }
            expect(output.item_created_by).to eq format('Committed by: %s',
                                                        login)
          end

          it 'returns the formatted pull request merger' do
            output.context.current[:type] = :pull_request
            output.context.current[:info] = { merged_by: { login: login } }
            expect(output.item_created_by).to eq format('Merged by: %s',
                                                        login)
          end
        end

        describe 'item_link' do
          let(:url) { 'https://example.org/test' }

          it 'returns the html formatted item link on a commit' do
            output.get_output_template_path('html')
            output.context.current[:type] = :commit
            output.context.current[:info] = { html_url: url }
            expect(output.item_link).to eq format('<a href="%s">%s</a>', url, url)
          end

          it 'returns the html formatted item link on a pull_request' do
            output.get_output_template_path('html')
            output.context.current[:type] = :pull_request
            output.context.current[:info] = { html_url: url }
            expect(output.item_link).to eq format('<a href="%s">%s</a>', url, url)
          end

          it 'returns the txt item link on a commit' do
            output.get_output_template_path('txt')
            output.context.current[:type] = :commit
            output.context.current[:info] = { html_url: url }
            expect(output.item_link).to eq url
          end

          it 'returns the txt item link on a pull_request' do
            output.get_output_template_path('txt')
            output.context.current[:type] = :pull_request
            output.context.current[:info] = { html_url: url }
            expect(output.item_link).to eq url
          end
        end

        context 'commits methods' do
          describe 'commits' do
          end

          describe 'has_commits' do
          end
        end

        describe 'format_link' do
          let(:url) { 'https://example.org/test' }

          it 'returns the html formatted item link on a commit' do
            output.get_output_template_path('html')
            expect(output.send(:format_link, url)).to eq format('<a href="%s">%s</a>', url, url)
          end

          it 'returns the txt item link on a commit' do
            output.get_output_template_path('txt')
            expect(output.send(:format_link, url)).to eq url
          end
        end
      end
    end
  end
end
