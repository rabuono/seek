module FilteringHelper
  def sorted_filters(filters)
    filters.sort_by do |filter|
      (filter[:active] ? -1000 : 0) - filter[:count]
    end
  end

  def filter_link(key, filter)
    link_to(page_and_sort_params.merge({ page: nil, filter: filter[:active] ? without_filter(key, filter[:value]) : with_filter(key, filter[:value]) }),
            title: filter[:title],
            class: "filter-option#{' filter-active' if filter[:active]}") do
      content_tag(:span, filter[:title], class: 'filter-title') +
          content_tag(:span, filter[:count], class: 'filter-count')
    end
  end

  def with_filter(key, value)
    existing = @filters[key]
    if existing
      existing = [existing] unless existing.is_a?(Array)
      existing |= [value]
    else
      existing = value
    end

    @filters.merge(key => existing)
  end

  def without_filter(key, value)
    existing = @filters[key]
    if existing
      existing = [existing] unless existing.is_a?(Array)
      existing -= [value]
    end

    if existing.empty?
      @filters.except(key)
    else
      @filters.merge(key => existing)
    end
  end
end
