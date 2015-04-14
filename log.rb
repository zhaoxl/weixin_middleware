module TianjiWechat
  #日志
  class Log
    #记录日志
    def self.info(msg)
      if block_given?
        log = WeixinLog.new(title: msg)
        yield(log)
        log.save
      end
      Rails.logger.info "TianjiWeichat.#{msg}"
    end
  end
end