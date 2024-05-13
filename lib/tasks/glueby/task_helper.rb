module TaskHelper
  def logger
    return Rails.logger if Rails.logger

    @logger ||= begin
                  logger = ActiveSupport::Logger.new(STDOUT)
                  logger.level = Logger::INFO
                  logger
                end
  end
end