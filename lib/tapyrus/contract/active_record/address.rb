module Tapyrus
  module Contract
    module AR
      class Address < ::ActiveRecord::Base
        belongs_to :account, dependent: :destroy

        scope :receive, -> { where(change: false).order('address_index DESC') }
        scope :change, -> { where(change: true).order('address_index DESC') }
      end
    end
  end
end
