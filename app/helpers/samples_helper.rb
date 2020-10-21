module SamplesHelper
  def sample_form_field_for_attribute(attribute)
    base_type = attribute.sample_attribute_type.base_type
    clz = "sample_attribute_#{base_type.downcase}"
    element_name = "sample[data][#{attribute.title}]"
    value = @sample.get_attribute_value(attribute.title)
    placeholder = "e.g. #{attribute.sample_attribute_type.placeholder}" unless attribute.sample_attribute_type.placeholder.blank?

    case base_type
    when Seek::Samples::BaseType::TEXT
      text_area_tag element_name,value, class: "form-control #{clz}"
    when Seek::Samples::BaseType::DATE_TIME
      content_tag :div, style:'position:relative' do
        text_field_tag element_name, value, data: { calendar: 'mixed' }, class: "calendar form-control #{clz}", placeholder: placeholder
      end
    when Seek::Samples::BaseType::DATE
      content_tag :div, style:'position:relative' do
        text_field_tag element_name, value, data: { calendar: true }, class: "calendar form-control #{clz}", placeholder: placeholder
      end
    when Seek::Samples::BaseType::BOOLEAN
      check_box_tag element_name, value, class: "#{clz}"
    when Seek::Samples::BaseType::SEEK_STRAIN
      options = option_groups_from_collection_for_select(Organism.all, :strains,
                                                         :title, :id,
                                                         :title, value.try(:[],'id'))
      select_tag(element_name, options, include_blank: !attribute.required?, class: "form-control #{clz}")
    when Seek::Samples::BaseType::CV
      terms = attribute.sample_controlled_vocab.sample_controlled_vocab_terms
      options = options_from_collection_for_select(terms, :label, :label, value)
      select_tag element_name, options,
                        include_blank: !attribute.required? , class: "form-control #{clz}"
    when Seek::Samples::BaseType::SEEK_SAMPLE
      terms = attribute.linked_sample_type.samples.authorized_for('view').to_a
      options = options_from_collection_for_select(terms, :id, :title, value.try(:[],'id'))
      select_tag element_name, options,
                 include_blank: !attribute.required? , class: "form-control #{clz}"
    else
      text_field_tag element_name,value, class: "form-control #{clz}", placeholder: placeholder
    end
  end

  def authorised_samples(projects = nil)
    authorised_assets(Sample, projects)
  end

  def sample_attribute_title_and_unit(attribute)
    title = attribute.title
    if (unit = attribute.unit) && !unit.dimensionless?
      title += " ( #{unit} )"
    end
    title
  end

  def display_attribute(sample, attribute, options = {})
    value = sample.get_attribute_value(attribute)
    if value.blank?
      text_or_not_specified(value)
    else
      case attribute.sample_attribute_type.base_type
      when Seek::Samples::BaseType::DATE
        Date.parse(value).strftime('%e %B %Y')
      when Seek::Samples::BaseType::DATE_TIME
        DateTime.parse(value).strftime('%e %B %Y %H:%M:%S')
      when Seek::Samples::BaseType::SEEK_STRAIN
        seek_strain_attribute_display(value)
      when Seek::Samples::BaseType::SEEK_SAMPLE
        seek_sample_attribute_display(value)
      else
        default_attribute_display(attribute, options, sample, value)
      end
    end
  end

  def seek_sample_attribute_display(value)
    sample = Sample.find_by_id(value['id'])
    if sample
      if sample.can_view?
        link_to sample.title, sample
      else
        content_tag :span, 'Hidden', class: 'none_text'
      end
    else
      content_tag :span, value['title'], class: 'none_text'
    end
  end

  def default_attribute_display(attribute, options, sample, value)
    resolution = attribute.resolve (value)
    if (resolution != nil)
      link_to(value, resolution, target: :_blank)
    else if options[:link] && attribute.is_title
        link_to(value, sample)
      else
      
        text_or_not_specified(value, auto_link: options[:link])
      end
    end
  end

  def seek_strain_attribute_display(value)
    if value && value['id']
      if value['title']
        link_to(value['title'], strain_path(value['id']))
      else
        content_tag(:span, value['id'], class: 'none_text')
      end
    else
      content_tag(:span, 'Not specified', class: 'none_text')
    end
  end

  # link for the sample type for the provided sample. Handles a referring_sample_id if required
  def sample_type_link(sample, user=User.current_user)
    if (sample.sample_type.can_view?(user))
      link_to sample.sample_type.title,sample.sample_type
    else
      link_to sample.sample_type.title,sample_type_path(sample.sample_type, referring_sample_id:sample.id)
    end
  end

  def sample_type_list_item_attribute(attribute, sample)
    value = sample_type_link(sample)
    html = content_tag(:p,class:'list_item_attribute') do
      content_tag(:b) do
        "#{attribute}: "
      end + value
    end
    html.html_safe
  end

end
