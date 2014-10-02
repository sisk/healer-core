module CustomMatchers
  def appointment_response_matches?(response, record)
    response_and_record_match?(
      response,
      record,
      APPOINTMENT_ATTRIBUTES,
      :time => %i(start_time end_time)
    )
  end

  def patient_response_matches?(response, record)
    response_and_record_match?(
      response,
      record,
      PATIENT_ATTRIBUTES,
      :date => %i(birth)
    )
  end

  def case_response_matches?(response, record)
    response_and_record_match?(
      response,
      record,
      CASE_ATTRIBUTES
    )
  end

  def attachment_response_matches?(response, record)
    response_and_record_match?(
      response,
      record,
      ATTACHMENT_ATTRIBUTES,
      :time => %i(created_at)
    )
  end

  def response_and_record_match?(response, record, attributes, custom_types = {})
    attributes.all? do |attr|
      value = response[attr.to_s.camelize(:lower)]
      if custom_types[:time] && custom_types[:time].include?(attr)
        Time.parse(value).iso8601.should == record.send(attr).iso8601
      elsif custom_types[:date] && custom_types[:date].include?(attr)
        value.should == record.send(attr).to_s(:db)
      else
        value.to_s.should == record.send(attr).to_s
      end
    end
  end
end