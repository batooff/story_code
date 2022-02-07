class Applications::MatchedApplications::FetchService
  attr_reader :application

  INTERVAL_DAYS = [7, 14, 30].freeze
  EXCLUDED_TYPES = %w[Application::MobileRepeat Application::Repeat Application::RepeatIl]

  def initialize(application)
    @application = application
  end

  def call
    Application
      .accepted_or_rejected
      .over_the_last_period(30.days.ago)
      .select(columns_to_select)
      .joins('LEFT JOIN user_stack_agents on applications.id = user_stack_agents.application_id')
      .where.not(type: EXCLUDED_TYPES)
      .where.not(id: application.id)
      .reorder('')
  end

  def columns_to_select
    result = []

    result << account_number_matched
    result << card_number_matched
    result << full_name_and_dob_matched
    result << email_matched
    result << document_number_matched
    result << mobile_phone_matched
    result << fingerprints_matched
    result << device_vendor_id_matched
    result << user_agent_matched

    result.flatten.join(', ')
  end

  private

  def hours_since_last_matched(filter_string, name)
    return "0 AS #{name}__hours" if filter_string.blank?

    "COALESCE(MIN((EXTRACT(epoch FROM age(now(), applications.created_at))/3600)::int) FILTER (WHERE #{filter_string}),0) AS #{name}__hours"
  end

  def number_of_matches_in_days(filter_string, name, day)
    return "0 AS #{name}__#{day}_days" if filter_string.blank?

    "COUNT (*) FILTER (WHERE completed_at > current_date - interval '#{day}' day AND #{filter_string}) AS #{name}__#{day}_days"
  end

  def conditions(filters, name)
    result = []

    filter_string = filters.any?(&:nil?) ? '' : filters.join(' AND ')

    result << hours_since_last_matched(filter_string, name)

    INTERVAL_DAYS.each do |day|
      result << number_of_matches_in_days(filter_string, name, day)
    end

    result
  end

  def transform_to_filter(column, value)
    "#{column} = '#{value}'" if value.present?
  end

  def account_number_matched
    filters = [
      transform_to_filter('applications.disbursement_channel', application.disbursement_channel),
      transform_to_filter('applications.bank_id', application.bank_id),
      transform_to_filter('applications.bank_account_number', application.bank_account_number),
    ]

    conditions(filters, __method__)
  end

  def card_number_matched
    filters = [
      transform_to_filter('applications.disbursement_channel', application.disbursement_channel),
      transform_to_filter('applications.bank_id', application.bank_id),
      transform_to_filter('applications.bank_card_number', application.bank_card_number)
    ]

    conditions(filters, __method__)
  end

  def full_name_and_dob_matched
    full_name = I18n.transliterate(application.full_name.to_s).upcase.gsub(/\s+/, '')

    filters = [
      transform_to_filter("regexp_replace(unaccent(upper(applications.full_name)), '\s', '', 'g')", full_name),
      transform_to_filter('applications.date_of_birth', application.date_of_birth&.to_s(:db))
    ]

    conditions(filters, __method__)
  end

  def email_matched
    filters = [
      transform_to_filter('applications.email', application.email)
    ]

    conditions(filters, __method__)
  end

  def document_number_matched
    filters = [
      transform_to_filter('applications.document_number', application.document_number)
    ]

    conditions(filters, __method__)
  end

  def mobile_phone_matched
    filters = [
      transform_to_filter('applications.mobile_phone', application.mobile_phone)
    ]

    conditions(filters, __method__)
  end

  def fingerprints_matched
    filters = [
      transform_to_filter('applications.fingerprints_visitor_id', application.fingerprints_visitor_id)
    ]

    conditions(filters, __method__)
  end

  def device_vendor_id_matched
    filters = [
      transform_to_filter('applications.device_vendor_id', application.device_vendor_id)
    ]

    conditions(filters, __method__)
  end

  def user_agent_matched
    filters = [
      transform_to_filter('applications.ip', application.ip),
      transform_to_filter('user_stack_agents.ua_brand', application.user_stack&.ua_brand),
      transform_to_filter('user_stack_agents.ua_name', application.user_stack&.ua_name),
      transform_to_filter('user_stack_agents.os_name', application.user_stack&.os_name)
    ]

    conditions(filters, __method__)
  end
end
