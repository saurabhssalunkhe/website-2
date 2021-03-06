require 'rails_helper'

RSpec.describe SpeakersController, type: :controller do

  describe '#index' do
    it 'returns http success' do
      get :index
      expect(response).to be_success
    end
  end

  describe '#new' do
    it 'returns http success' do
      get :new
      expect(response).to be_success
    end
  end

  describe '#create' do
    let(:speaker_attributes) { attributes_for :speaker }

    it 'creates a speaker' do
      expect_any_instance_of(SpeakersController).to receive(:add_to_list)
      expect { post :create, speaker: speaker_attributes }.
        to change{ Speaker.count }.from(0).to(1)
    end

    it 'redirects to the thank you page' do
      expect(post :create, speaker: speaker_attributes).
        to redirect_to thanks_speaker_path(Speaker.last)
    end
  end
end
