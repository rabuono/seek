module Seek
  module Stats
    class DashboardStats
      def initialize(scope = nil)
        @scope = scope
      end

      def asset_activity(action, start_date, end_date, type: nil)
        resource_types = type || Seek::Util.asset_types.map(&:name)
        Rails.cache.fetch("#{cache_key_base}_#{type || 'all'}_activity_#{action}_#{start_date}_#{end_date}", expires_in: 12.hours) do
          scoped_activities
            .where(action: action)
            .where('created_at > ? AND created_at < ?', start_date, end_date)
            .where(activity_loggable_type: resource_types)
            .group(:activity_loggable_type, :activity_loggable_id).count.to_a
            .map { |(type, id), count| [type.constantize.find_by_id(id), count] }
            .select { |resource, _| !resource.nil? && resource.can_view? }
            .sort_by { |x| -x[1] }.first(10)
        end
      end

      def contributor_activity(start_date, end_date)
        Rails.cache.fetch("#{cache_key_base}_contributor_activity_#{start_date}_#{end_date}", expires_in: 12.hours) do
          scoped_activities
            .where(action: %w[update create])
            .where('created_at > ? AND created_at < ?', start_date, end_date)
            .group(:culprit_type, :culprit_id).count.to_a
            .map { |(type, id), count| [type.constantize.find_by_id(id).try(:person), count] }
            .reject { |resource, _| resource.nil? }
            .sort_by { |x| -x[1] }
            .first(10)
        end
      end

      def contributions(start_date, end_date, interval)
        Rails.cache.fetch("#{cache_key_base}_contributions_#{interval}_#{start_date}_#{end_date}", expires_in: 12.hours) do
          strft = case interval
                  when 'year'
                    '%Y'
                  when 'month'
                    '%B %Y'
                  when 'day'
                    '%Y-%m-%d'
                  end

          assets = (@scope.nil? ? (Programme.all + Project.all) : []) + scoped_resources
          assets.select! { |a| a.created_at >= start_date && a.created_at <= end_date }
          date_grouped = assets.group_by { |a| a.created_at.strftime(strft) }
          types = assets.map(&:class).uniq
          dates = dates_between(start_date, end_date, interval)

          labels = dates.map { |d| d.strftime(strft) }
          datasets = {}
          types.each do |type|
            datasets[type] = dates.map do |date|
              assets_for_date = date_grouped[date.strftime(strft)]
              assets_for_date ? assets_for_date.select { |a| a.class == type }.count : 0
            end
          end
          { labels: labels, datasets: datasets }
        end
      end

      def asset_accessibility(start_date, end_date, type: nil)
        Rails.cache.fetch("#{cache_key_base}_#{type || 'all'}_asset_accessibility_#{start_date}_#{end_date}", expires_in: 3.hours) do
          assets = scoped_resources
          assets.select! { |a| a.class.name == type } if type
          assets.select! { |a| a.created_at >= start_date && a.created_at <= end_date }
          published_count = assets.count(&:is_published?)
          private_count = assets.count(&:private?)
          misc_permissions = assets.count - (published_count + private_count)
          { published: published_count, restricted: misc_permissions, private: private_count }
        end
      end

      def clear_caches
        Rails.cache.delete_matched(/#{cache_key_base}/)
      end

      private

      def cache_key_base
        if @scope
          "#{@scope.class.name}_#{@scope.id}_dashboard_stats"
        else
          'admin_dashboard_stats'
        end
      end

      def scoped_activities
        @activities ||= if @scope
                          ActivityLog.where(referenced_id: @scope.id, referenced_type: @scope.class.name)
                        else
                          ActivityLog
                        end
      end

      def scoped_resources
        @resources ||= (scoped_isa + scoped_assets)
      end

      def scoped_assets
        @assets ||= if @scope
                      (@scope.assets + @scope.samples)
                    else
                      Seek::Util.asset_types.map(&:all).flatten
                    end
      end

      def scoped_isa
        @isa ||= if @scope
                   @scope.investigations + @scope.studies + @scope.assays
                 else
                   Investigation.all + Study.all + Assay.all
                 end
      end

      def dates_between(start_date, end_date, interval = 'month')
        case interval
        when 'year'
          transform = ->(date) { Date.parse("#{date.strftime('%Y')}-01-01") }
          increment = ->(date) { date >> 12 }
        when 'month'
          transform = ->(date) { Date.parse("#{date.strftime('%Y-%m')}-01") }
          increment = ->(date) { date >> 1 }
        when 'day'
          transform = ->(date) { date }
          increment = ->(date) { date + 1 }
        else
          raise 'Invalid interval. Valid intervals: year, month, day'
        end

        start_date = transform.call(start_date)
        end_date = transform.call(end_date)
        date = start_date
        dates = []

        while date <= end_date
          dates << date
          date = increment.call(date)
        end

        dates
      end
    end
  end
end
