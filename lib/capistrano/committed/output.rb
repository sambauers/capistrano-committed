require 'mustache'

module Capistrano
  module Committed
    class Output < Mustache
      @@template_format = 'txt'

      self.template_path = format('%s/output', File.dirname(__FILE__))
      self.template_file = format('%s/output/output_%s.mustache', File.dirname(__FILE__), @@template_format)

      def get_output_path(file)
        format('%s/output/%s', File.dirname(__FILE__), file)
      end

      def get_output_template_path(format = 'txt', set_template_format = true)
        @@template_format = format if set_template_format
        get_output_path(format('output_%s.mustache', format))
      end

      def template_format
        @@template_format
      end

      def release_header
        case context.current[:release]
        when :next
          t('committed.output.next_release')
        when :previous
          t('committed.output.previous_release',
            time: context.current[:date])
        else
          t('committed.output.current_release',
            release_time: Time.parse(context.current[:release]).iso8601,
            sha: context.current[:sha],
            commit_time: context.current[:date])
        end
      end

      def items
        return unless context.current[:entries]
        Hash[context.current[:entries].sort_by { |date, _entries| date }.reverse].values.flatten
      end

      def item_title
        return unless context.current[:info]
        case context.current[:type]
        when :commit
          t('committed.output.commit_sha',
            sha: context.current[:info][:sha])
        when :pull_request
          t('committed.output.pull_request_number',
            number: context.current[:info][:number])
        end
      end

      def item_subtitle
        return unless context.current[:type] == :pull_request
        return unless context.current[:info]
        context.current[:info][:title]
      end

      def has_item_subtitle
        !item_subtitle.nil?
      end

      def item_lines
        return unless context.current[:info]
        case context.current[:type]
        when :commit
          message = context.current[:info][:commit][:message]
        when :pull_request
          message = context.current[:info][:body]
        end
        message.nil? ? [] : message.chomp.delete("\r").split("\n")
      end

      def has_item_lines
        !item_lines.empty?
      end

      def issue_links
        return unless context.current[:info]
        case context.current[:type]
        when :commit
          return unless context.current[:info][:commit]
          ::Capistrano::Committed.get_issue_urls(context.current[:info][:commit][:message])
        when :pull_request
          ::Capistrano::Committed.get_issue_urls(context.current[:info][:title] + context.current[:info][:body])
        end
      end

      def issue_link
        format_link(context.current)
      end

      def has_issue_links
        !issue_links.empty?
      end

      def item_created_on
        return unless context.current[:info]
        case context.current[:type]
        when :commit
          return unless context.current[:info][:commit] && context.current[:info][:commit][:committer]
          t('committed.output.committed_on', time: context.current[:info][:commit][:committer][:date])
        when :pull_request
          return unless context.current[:info][:merged_at]
          t('committed.output.merged_on', time: context.current[:info][:merged_at])
        end
      end

      def item_created_by
        return unless context.current[:info]
        case context.current[:type]
        when :commit
          info_key = :committer
          t_key = 'committed.output.committed_by'
        when :pull_request
          info_key = :merged_by
          t_key = 'committed.output.merged_by'
        else
          return
        end
        
        return unless context.current[:info][info_key]
        t(t_key, login: context.current[:info][info_key][:login])
      end

      def item_link
        return unless context.current[:info]
        case context.current[:type]
        when :commit, :pull_request
          return unless context.current[:info][:html_url]
          format_link(context.current[:info][:html_url])
        end
      end

      def commits
        return unless context.current[:type] == :pull_request
        return unless context.current[:commits]
        return if context.current[:commits].empty?
        context.current[:commits].flatten
      end

      def has_commits
        !commits.nil?
      end

    private

      def format_link(url)
        case template_format
        when 'html'
          format('<a href="%s">%s</a>', url, url)
        when 'txt'
          url
        end
      end
    end
  end
end
