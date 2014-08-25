require "spec_helper"

def validate_response_matches_persisted(response, persisted)
  APPOINTMENT_ATTRIBUTES.each do |attr|
    if %i(start_time end_time).include?(attr)
      Time.parse(response[attr.to_s]).iso8601.should == persisted.send(attr).iso8601
    else
      response[attr.to_s].should == persisted.send(attr)
    end
  end
  PATIENT_ATTRIBUTES.each do |attr|
    if attr == :birth
      response["patient"][attr.to_s].should == persisted.patient.send(attr).to_s(:db)
    else
      response["patient"][attr.to_s].should == persisted.patient.send(attr)
    end
  end
end

describe "appointments", type: :api do

  let(:valid_request_attributes) { { "client_id" => "healer_spec" } }

  describe "GET index" do
    before(:each) do
      @persisted_1 = FactoryGirl.create(:appointment)
      @persisted_2 = FactoryGirl.create(:appointment)
    end

    it "returns 400 if no client_id is supplied" do
      get "/appointments"

      expect_missing_client_response
    end

    it "returns all appointments as JSON, along with patient data" do
      get "/appointments", valid_request_attributes

      response.code.should == "200"
      response_body = JSON.parse(response.body)
      response_records = response_body["appointments"]
      response_records.size.should == 2
      response_records.map{ |r| r["id"] }.any?{ |id| id.nil? }.should == false

      response_record_1 = response_records.detect{ |r| r["id"] == @persisted_1.id }
      response_record_2 = response_records.detect{ |r| r["id"] == @persisted_2.id }

      validate_response_matches_persisted(response_record_1, @persisted_1)
      validate_response_matches_persisted(response_record_2, @persisted_2)
    end

    it "filters by location" do
      @persisted_2.update_attributes!(location: "room 1")

      get "/appointments", valid_request_attributes.merge(location: "room 1")

      response.code.should == "200"
      response_body = JSON.parse(response.body)
      response_records = response_body["appointments"]
      response_records.size.should == 1
      response_records.first["id"].should == @persisted_2.id
    end

    it "filters by trip_id" do
      @persisted_1.update_attributes!(trip_id: "2")

      get "/appointments", valid_request_attributes.merge(trip_id: "2")

      response.code.should == "200"
      response_body = JSON.parse(response.body)
      response_records = response_body["appointments"]
      response_records.size.should == 1
      response_records.first["id"].should == @persisted_1.id
    end

    it "filters by multiple criteria" do
      @persisted_1.update_attributes!(location: "room 1", trip_id: "1")
      @persisted_2.update_attributes!(location: "room 1", trip_id: "2")

      get "/appointments", valid_request_attributes.merge(
        location: "room 1", trip_id: "2"
      )

      response.code.should == "200"
      response_body = JSON.parse(response.body)
      response_records = response_body["appointments"]
      response_records.size.should == 1
      response_records.first["id"].should == @persisted_2.id
    end

    it "does not include records belonging to deleted patients" do
      persisted_3 = FactoryGirl.create(
        :appointment,
        patient: FactoryGirl.create(:deleted_patient)
      )

      get "/appointments", valid_request_attributes

      response.code.should == "200"
      response_body = JSON.parse(response.body)
      response_records = response_body["appointments"]

      response_records.map{ |r| r["id"] }.should_not include(persisted_3.id)
    end
  end

  describe "GET show" do
    before(:each) do
      @persisted_patient = FactoryGirl.create(:patient)
      @persisted_record = FactoryGirl.create(:appointment, patient: @persisted_patient)
    end

    it "returns 400 if no client_id is supplied" do
      get "/appointments/#{@persisted_record.id}"

      expect_missing_client_response
    end

    it "returns a single persisted record as JSON" do
      get "/appointments/#{@persisted_record.id}", valid_request_attributes

      response.code.should == "200"
      response_record = JSON.parse(response.body)["appointment"]

      validate_response_matches_persisted(response_record, @persisted_record)
    end

    it "returns 404 if there is no persisted record" do
      get "/appointments/#{@persisted_record.id + 1}", valid_request_attributes

      response.code.should == "404"
      response_body = JSON.parse(response.body)
      response_body["error"]["message"].should == "Not Found"
    end

    it "returns 404 if patient is deleted" do
      persisted_record = FactoryGirl.create(:appointment,
        patient: FactoryGirl.create(:deleted_patient)
      )

      get "/appointments/#{persisted_record.id}", valid_request_attributes

      response.code.should == "404"
      response_body = JSON.parse(response.body)
      response_body["error"]["message"].should == "Not Found"
    end
  end#show

  describe "POST create" do
    it "returns 400 if no client_id is supplied" do
      patient = FactoryGirl.create(:patient)
      attributes = FactoryGirl.attributes_for(:appointment).merge!(
        patient_id: patient.id
      )

      post "/appointments", appointment: attributes

      expect_missing_client_response
    end

    it "persists a new patient-associated record and returns JSON" do
      patient = FactoryGirl.create(:patient)
      attributes = FactoryGirl.attributes_for(:appointment).merge!(
        patient_id: patient.id
      )

      expect {
        post "/appointments", valid_request_attributes.merge(
          appointment: attributes
        )
      }.to change(Appointment, :count).by(1)

      response.code.should == "201"

      response_record = JSON.parse(response.body)["appointment"]

      persisted_record = Appointment.last

      persisted_record.patient_id.should == patient.id
      APPOINTMENT_ATTRIBUTES.each do |attr|
        attributes[attr].should == persisted_record.send(attr)
      end
      PATIENT_ATTRIBUTES.each do |attr|
        response_record["patient"][attr.to_s].to_s.should == patient.send(attr).to_s
      end
    end

    it "returns 400 if a patient id is not supplied" do
      attributes = FactoryGirl.attributes_for(:appointment)
      attributes.should_not include(:patient_id)

      expect {
        post "/appointments", valid_request_attributes.merge(
          appointment: attributes
        )
      }.to_not change(Appointment, :count)

      response.code.should == "400"
      response_body = JSON.parse(response.body)
      response_body["error"]["message"].should match(/patient/i)
    end

    it "returns 404 if patient is not found matching id" do
      attributes = FactoryGirl.attributes_for(:appointment).merge!(patient_id: 1)
      Patient.find_by_id(1).should be_nil

      expect {
        post "/appointments", valid_request_attributes.merge(
          appointment: attributes
        )
      }.to_not change(Appointment, :count)

      response.code.should == "404"
      response_body = JSON.parse(response.body)
      response_body["error"]["message"].should == "Not Found"
    end

    it "returns 404 if patient is deleted" do
      patient = FactoryGirl.create(:deleted_patient)
      attributes = FactoryGirl.attributes_for(:appointment).merge!(patient_id: patient.id)

      expect {
        post "/appointments", valid_request_attributes.merge(
          appointment: attributes
        )
      }.to_not change(Appointment, :count)

      response.code.should == "404"
    end
  end

  describe "PUT update" do
    it "returns 400 if no client_id is supplied" do
      persisted_record = FactoryGirl.create(:appointment)
      new_attributes = { start_time: Time.now.utc + 1.week }

      put "/appointments/#{persisted_record.id}", appointment: new_attributes

      expect_missing_client_response
    end

    it "updates an existing appointment record" do
      persisted_record = FactoryGirl.create(:appointment)
      new_attributes = {
        start_time: Time.now.utc + 1.week,
        start_ordinal: 5,
        location: "room 1",
        end_time: Time.now.utc + 2.weeks
      }

      new_attributes.each do |k,v|
        persisted_record.send(k).should_not == v
      end

      put "/appointments/#{persisted_record.id}", valid_request_attributes.merge(
        appointment: new_attributes
      )

      response_record = JSON.parse(response.body)["appointment"]
      persisted_record.reload

      response.code.should == "200"
      attribute_keys = new_attributes.keys
      APPOINTMENT_ATTRIBUTES.each do |attr|
        if attribute_keys.include?(attr)
          if %i(start_time end_time).include?(attr)
            Time.parse(response_record[attr.to_s]).iso8601.should == persisted_record.send(attr).iso8601
            Time.parse(response_record[attr.to_s]).iso8601.should == new_attributes[attr].iso8601
          else
            response_record[attr.to_s].should == persisted_record.send(attr)
            response_record[attr.to_s].should == new_attributes[attr]
          end
        end
      end
    end

    it "does not allow transfer to another patient" do
      patient = FactoryGirl.create(:patient)
      different_patient = FactoryGirl.create(:patient)
      persisted_record = FactoryGirl.create(:appointment, patient: patient)
      new_attributes = {
        start_ordinal: 5,
        patient_id: different_patient.id
      }

      put "/appointments/#{persisted_record.id}", valid_request_attributes.merge(
        appointment: new_attributes
      )

      persisted_record.reload
      persisted_record.patient_id.should == patient.id
    end

    it "does not update patient information" do
      patient = FactoryGirl.create(:patient)
      original_patient_name = patient.name
      persisted_record = FactoryGirl.create(:appointment, patient: patient)
      new_attributes = {
        start_ordinal: 500,
        patient: {
          name: "New Patient Name"
        }
      }

      put "/appointments/#{persisted_record.id}", valid_request_attributes.merge(
        appointment: new_attributes
      )

      persisted_record.reload
      persisted_record.patient.reload.should == patient
      persisted_record.patient.name.should == original_patient_name
    end

    it "returns 404 if patient is deleted" do
      patient = FactoryGirl.create(:deleted_patient)
      persisted_record = FactoryGirl.create(:appointment, patient: patient)
      new_attributes = {
        start_time: Time.now + 1.week,
        start_ordinal: 5
      }

      put "/appointments/#{persisted_record.id}", valid_request_attributes.merge(
        appointment: new_attributes
      )

      response.code.should == "404"
    end
  end

  describe "DELETE" do
    it "returns 400 if no client_id is supplied" do
      persisted_record = FactoryGirl.create(:appointment)

      delete "/appointments/#{persisted_record.id}"

      expect_missing_client_response
    end

    it "hard-deletes an existing persisted record" do
      persisted_record = FactoryGirl.create(:appointment)

      delete "/appointments/#{persisted_record.id}", valid_request_attributes

      response.code.should == "200"
      response_body = JSON.parse(response.body)
      response_body["message"].should == "Deleted"

      persisted_record.class.find_by_id(persisted_record.id).should be_nil
    end

    it "returns 404 if persisted record does not exist" do
      delete "/appointments/100", valid_request_attributes

      response.code.should == "404"
      response_body = JSON.parse(response.body)
      response_body["error"]["message"].should == "Not Found"
    end
  end#delete

end