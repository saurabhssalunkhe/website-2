require 'rails_helper'

RSpec.describe Order, :type => :model do
  let(:order) { build_stubbed(:order) }

  describe '#to_param' do
    it { expect(order.to_param).to eq order.identifier }
  end

  describe '#current_step=' do
    context 'when set to an existing step' do
      let(:set_step) { 'confirmation' }
      before { order.current_step = set_step }
      it { expect(order.current_step).to eq set_step }
    end

    context 'when passed a non-existing step' do
      it 'should raise an ArgumentError' do
        expect { order.current_step = 'foobar' }.to raise_error ArgumentError
      end
    end
  end

  describe '#current_step' do
    it { expect(order.current_step).to eq order.steps.first }

    context 'when set' do
      let(:set_step) { 'confirmation' }
      before { order.current_step = set_step }
      it { expect(order.current_step).to eq set_step }
    end
  end

  describe '#steps' do
    let(:num_students) { 1 }
    before do
      allow(order).
        to receive(:cart_sum_tickets).
        and_return(num_students)
    end
    it { expect(order.steps).to eq %w(tickets details students-0 confirmation) }

    context 'with multiple students' do
      let(:num_students) { 4 }
      it { expect(order.steps).to eq %w(tickets details students-0 students-1 students-2 students-3 confirmation) }
    end
  end

  describe '#next_step' do
    it { expect(order.next_step).to eq 'details' }

    context 'dynamicly generated student steps' do
      before do
        allow(order).
          to receive(:cart_sum_tickets).
          and_return(2)

        order.current_step = 'students-0'
      end

      it { expect(order.next_step).to eq 'students-1' }
    end

    context 'last step' do
      before { order.current_step = order.steps.last }
      it { expect(order.next_step).to eq order.steps.last }
    end
  end

  describe '#previous_step' do
    before { order.current_step = 'details' }
    it { expect(order.previous_step).to eq 'tickets' }

    context 'dynamicly generated student steps' do
      before do
        allow(order).
          to receive(:cart_sum_tickets).
          and_return(2)

        order.current_step = 'students-1'
      end

      it { expect(order.previous_step).to eq 'students-0' }
    end

    context 'first step' do
      before { order.current_step = order.steps.first }
      it { expect(order.previous_step).to eq order.steps.first }
    end
  end

  describe '#first_step?' do
    it { expect(order.first_step?).to be true }

    context 'later step' do
      before { order.current_step = 'details' }
      it { expect(order.first_step?).to be false }
    end
  end

  describe '#last_step?' do
    it { expect(order.last_step?).to be false }

    context 'last step' do
      before { order.current_step = order.steps.last }
      it { expect(order.last_step?).to be true }
    end
  end
end