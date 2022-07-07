# frozen_string_literal: true

RSpec.describe 'Glueby::Util::Digest' do
  class Test include Glueby::Util::Digest
  end

  describe '#digest_content' do
    subject { Test.new.digest_content(content, digest) }

    let(:content) { 'content' }
    let(:digest) { :sha256 }

    it { expect(subject).to eq 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73' }

    context 'double_sha256' do
      let(:digest) { :double_sha256 }

      it { expect(subject).to eq 'c4eec85eb66b79b8f59ff76a97d5d97aac1b5eca8c6675b4e988a5deea786e53' }
    end

    context 'none' do
      let(:digest) { :none }

      it { expect(subject).to eq 'content' }
    end
  end
end
