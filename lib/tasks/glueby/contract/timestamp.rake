module Glueby
  module Contract
    module Task
      module Timestamp
        module_function
        extend Glueby::Contract::TxBuilder
        extend Glueby::Contract::Timestamp::Util

        def create
          timestamps = Glueby::Contract::AR::Timestamp.where(status: :init)
          fee_estimator = Glueby::Contract::FixedFeeEstimator.new
          timestamps.each { |t| t.save_with_broadcast(fee_estimator: fee_estimator) }
        end
      end
    end
  end
end

namespace :glueby do
  namespace :contract do
    namespace :timestamp do
      desc 'create and broadcast glueby timestamp tx'
      task :create, [] => [:environment] do |_, _|
        Glueby::Contract::Task::Timestamp.create
      end
    end
  end
end