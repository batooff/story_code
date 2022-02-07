require 'rails_helper'

RSpec.describe Applications::MatchedApplications::FetchService do
  describe 'matched application statistics' do
    let(:valid_full_name) { 'Bruno Mars' }

    context 'account_number_matched' do
      it 'returns right number of values' do
        options =  {
          full_name: valid_full_name,
          disbursement_channel: 'bank_account',
          bank_account_number: Faker::Number.number(digits: 9),
          bank_id: 1,
          status: %w[accepted rejected].sample,
          type: 'Application::Web'
        }

        create(:application, options.merge(completed_at: DateTime.current - 1.day))
        create(:application, options.merge(completed_at: DateTime.current - 3.day))
        create(:application, options.merge(completed_at: DateTime.current - 19.day))

        application = create(:application, options.merge(completed_at: DateTime.current))

        result = described_class.new(application).call

        expect(result[0]['account_number_matched__hours']).to eq(0)
        expect(result[0]['account_number_matched__7_days']).to eq(2)
        expect(result[0]['account_number_matched__14_days']).to eq(2)
        expect(result[0]['account_number_matched__30_days']).to eq(3)
      end
    end

    context 'full_name_and_dob_matched' do
      it 'returns right number of values' do
        options =  {
          full_name: valid_full_name,
          date_of_birth: Date.current - 28.years,
          status: %w[accepted rejected].sample,
          type: 'Application::Web'
        }

        create(:application, options.merge(completed_at: DateTime.current - 1.day))
        create(:application, options.merge(completed_at: DateTime.current - 18.day))
        create(:application, options.merge(completed_at: DateTime.current - 19.day))

        application = create(:application, options.merge(completed_at: DateTime.current))

        result = described_class.new(application).call

        expect(result[0]['full_name_and_dob_matched__hours']).to eq(0)
        expect(result[0]['full_name_and_dob_matched__7_days']).to eq(1)
        expect(result[0]['full_name_and_dob_matched__14_days']).to eq(1)
        expect(result[0]['full_name_and_dob_matched__30_days']).to eq(3)
      end
    end

    context 'email_matched' do
      it 'returns right number of values' do
        options =  {
          full_name: valid_full_name,
          email: Faker::Internet.email,
          status: %w[accepted rejected].sample,
          type: 'Application::Web'
        }

        create(:application, options.merge(completed_at: DateTime.current - 8.day))
        create(:application, options.merge(completed_at: DateTime.current - 9.day))
        create(:application, options.merge(completed_at: DateTime.current - 19.day))

        application = create(:application, options.merge(completed_at: DateTime.current))

        result = described_class.new(application).call

        expect(result[0]['email_matched__hours']).to eq(0)
        expect(result[0]['email_matched__7_days']).to eq(0)
        expect(result[0]['email_matched__14_days']).to eq(2)
        expect(result[0]['email_matched__30_days']).to eq(3)
      end
    end

    context 'document_number_matched' do
      it 'returns right number of values' do
        options =  {
          full_name: valid_full_name,
          document_number: Faker::Number.number(digits: 9).to_s,
          status: %w[accepted rejected].sample,
          type: 'Application::Web'
        }

        create(:application, options.merge(completed_at: DateTime.current - 9.day, created_at: DateTime.current - 9.hours))
        create(:application, options.merge(completed_at: DateTime.current - 11.day, created_at: DateTime.current - 1.day))
        create(:application, options.merge(completed_at: DateTime.current - 25.day, created_at: DateTime.current - 1.day))

        application = create(:application, options.merge(completed_at: DateTime.current))

        result = described_class.new(application).call

        expect(result[0]['document_number_matched__hours']).to eq(9)
        expect(result[0]['document_number_matched__7_days']).to eq(0)
        expect(result[0]['document_number_matched__14_days']).to eq(2)
        expect(result[0]['document_number_matched__30_days']).to eq(3)
      end
    end

    context 'mobile_phone_matched' do
      it 'returns right number of values' do
        options =  {
          full_name: valid_full_name,
          mobile_phone: "+84#{Faker::Number.number(digits: 9)}",
          status: %w[accepted rejected].sample,
          type: 'Application::Web'
        }

        create(:application, options.merge(completed_at: DateTime.current - 1.day))
        create(:application, options.merge(completed_at: DateTime.current - 23.day))
        create(:application, options.merge(completed_at: DateTime.current - 25.day))

        application = create(:application, options.merge(completed_at: DateTime.current))

        result = described_class.new(application).call

        expect(result[0]['mobile_phone_matched__hours']).to eq(0)
        expect(result[0]['mobile_phone_matched__7_days']).to eq(1)
        expect(result[0]['mobile_phone_matched__14_days']).to eq(1)
        expect(result[0]['mobile_phone_matched__30_days']).to eq(3)
      end
    end
  end
end
