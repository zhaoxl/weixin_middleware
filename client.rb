module TianjiWechat
  #客户端类
  class Client
    
    #获取token，过期会自动刷新
    def self.token
      return $cache.get("tianji_wechat_client_token") || refresh_token
    end
    
    #刷新token
    def self.refresh_token
      retry_num = 0
      begin
        request = Nestful.get "https://api.weixin.qq.com/cgi-bin/token", { :grant_type => 'client_credential', :appid => API, :secret => KEY }
        auth = MultiJson.load(request.body)
        unless auth.has_key?('errcode')
          #直接将token加入redis缓存
          $cache.set("tianji_wechat_client_token", auth['access_token'], expires_in: auth['expires_in'].to_i)
          Log.info("Client.refresh_token success") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_SERVER
            log.state = WeixinLog::STATE_OK
            log.to_user = nil
            log.from_user = nil
            log.timestamp = nil
            log.message_type = nil
            log.message_content = nil
            log.exception_content = nil
            log.error_code = nil
          end
          return auth['access_token']
        else
          Log.info("Client.refresh_token failed :#{auth.to_s}") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_SERVER
            log.state = WeixinLog::STATE_FAILED
            log.to_user = nil
            log.from_user = nil
            log.timestamp = nil
            log.message_type = nil
            log.message_content = nil
            log.exception_content = nil
            log.error_code = auth['errcode']
          end
          if [-1, 42002].include?(auth['errcode'].to_i)
            raise ClientTokenException, auth['errcode'].to_i
          else
            return false
          end
        end
      rescue ClientTokenException => ex
        #如果token过期就重新获取token再试一次
        if (retry_num += 1) < 3
          msg = <<-STR
          Client.refresh_token Failed try again
          #{retry_num}st retry...
          STR
          Log.info(msg)
          retry
        else
          return false
        end
      rescue Exception => ex
        exception_msg = <<-STR
          Middleware.refresh_token exception>>>>>>>>>>>>>>>>>>>>
          #{ex.message}
          #{ex.backtrace}
        STR
        Log.info("Middleware.refresh_token exception") do |log|
          log.user_id = nil
          log.log_type = WeixinLog::TYPE_SERVER
          log.state = WeixinLog::STATE_EXCEPTION
          log.to_user = nil
          log.from_user = nil
          log.timestamp = nil
          log.message_type = nil
          log.message_content = nil
          log.exception_content = exception_msg
          log.error_code = nil
        end
      end
      return false
    end
    
    #发送消息
    def send(message)
      retry_num = 0
      begin
        response = Nestful::Connection.new("https://api.weixin.qq.com/cgi-bin").post("/cgi-bin/message/custom/send?access_token=#{self.class.token}", MultiJson.dump(message))
        errcode = MultiJson.load(response.body)['errcode']
        if errcode.to_i == 0
          Log.info("Client.send Server send message to client") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_SERVER
            log.state = WeixinLog::STATE_OK
            log.to_user = message["touser"]
            log.from_user = nil
            log.timestamp = nil
            log.message_type = message["msgtype"]
            log.message_content = message
            log.exception_content = nil
            log.error_code = nil
          end
          return true
        else
          Log.info("Client.send Server send message to client failed") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_SERVER
            log.state = WeixinLog::STATE_FAILED
            log.to_user = message["touser"]
            log.from_user = nil
            log.timestamp = nil
            log.message_type = message["msgtype"]
            log.message_content = message
            log.exception_content = nil
            log.error_code = errcode
          end
          if [40001, 40014, 41001, 42001].include?(errcode.to_i)
            raise ClientTokenException, errcode.to_i
          else
            return false
          end
        end
      rescue ClientTokenException => ex
        #如果token过期就重新获取token再试一次
        if (retry_num += 1) < 3
          msg = <<-STR
          Client.send Token expired refresh token and try again
          #{retry_num}st retry...
          STR
          Log.info(msg)
          self.class.refresh_token
          retry
        else
          return false
        end
      rescue Exception => ex
        exception_msg = <<-STR
          Client.send Server send message to client exception>>>>>>>>>>>>>>>>>>>>
          #{ex.message}
          #{ex.backtrace}
        STR
        Log.info("Client.send Server send message to client exception") do |log|
          log.user_id = nil
          log.log_type = WeixinLog::TYPE_SERVER
          log.state = WeixinLog::STATE_EXCEPTION
          log.to_user = message["touser"]
          log.from_user = nil
          log.timestamp = nil
          log.message_type = message["msgtype"]
          log.message_content = message
          log.exception_content = exception_msg
          log.error_code = nil
        end
      end
    end
    
    #获取菜单
    def menu_get
      request = Nestful::Connection.new("https://api.weixin.qq.com").get("/cgi-bin/menu/get?access_token=#{self.class.token}") rescue nil
      MultiJson.load(request.body) unless request.nil?
    end
    
    #更新菜单
    def menu_update(menu)
      retry_num = 0
      begin
        response = Nestful::Connection.new("https://api.weixin.qq.com").post("/cgi-bin/menu/create?access_token=#{self.class.token}", MultiJson.dump(menu))
        errcode = MultiJson.load(response.body)['errcode']
        if errcode.to_i == 0
          Log.info("Client.menu_update Update menu to weixin") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_SERVER
            log.state = WeixinLog::STATE_OK
            log.to_user = nil
            log.from_user = nil
            log.timestamp = nil
            log.message_type = "json"
            log.message_content = menu.to_json
            log.exception_content = nil
            log.error_code = nil
          end
          return true
        else
          Log.info("Client.menu_update Update menu to weixin failed") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_SERVER
            log.state = WeixinLog::STATE_FAILED
            log.to_user = nil
            log.from_user = nil
            log.timestamp = nil
            log.message_type = "json"
            log.message_content = menu.to_json
            log.exception_content = nil
            log.error_code = errcode
            return false, errcode
          end
          if [40001, 40014, 41001, 42001].include?(errcode.to_i)
            raise ClientTokenException, errcode.to_i
          else
            return false, errcode
          end
        end
      rescue ClientTokenException => ex
        #如果token过期就重新获取token再试一次
        retry_num += 1
        if retry_num < 3
          msg = <<-STR
          Client.menu_update Token expired refresh token and try again
          #{retry_num}st retry...
          STR
          Log.info(msg)
          self.class.refresh_token
          retry
        else
          return false
        end
      rescue Exception => ex
        exception_msg = <<-STR
          Client.menu_update Update menu to weixin exception>>>>>>>>>>>>>>>>>>>>
          #{ex.message}
          #{ex.backtrace}
        STR
        Log.info("Client.menu_update Update menu to weixin exception") do |log|
          log.user_id = nil
          log.log_type = WeixinLog::TYPE_SERVER
          log.state = WeixinLog::STATE_EXCEPTION
          log.to_user = nil
          log.from_user = nil
          log.timestamp = nil
          log.message_type = "json"
          log.message_content = menu.to_json
          log.exception_content = exception_msg
          log.error_code = nil
        end
      end
    end

    def self.qrcode(user_id)
      if $cache.get("qrcode_#{user_id}").blank?
        response = Typhoeus::Request.post("https://api.weixin.qq.com/cgi-bin/qrcode/create?access_token=#{token}",
                                          body:{expire_seconds: 1800, action_name: "QR_SCENE", action_info: {scene: {scene_id: user_id}}}.to_json)
        body = JSON.parse(response.body)
        if body["errcode"].present?
          $qrcode_logger.info("获取二维码ticket | user_id: #{user_id} | errcode: #{body['errcode']} | errmsg: #{body['errmsg']} | time: #{Time.now}")
          raise "access qrcode ticket failed"
        else
          ticket = body["ticket"]
          qrcode = Typhoeus::Request.get("https://mp.weixin.qq.com/cgi-bin/showqrcode?ticket=#{ticket}")
          if qrcode.code == 200
            $cache.set("qrcode_#{user_id}", qrcode.body, expires_in: 29.minutes)
          else
            $qrcode_logger.info("二维码ticket换取二维码图像| user_id: #{user_id} | status: #{qrcode.code} | time: #{Time.now}")
            raise "ticket error"
          end
        end
      end
      $cache.get("qrcode_#{user_id}")
    end

    def self.get_jsapi_ticket
      $cache.get("wechat_jsapi_ticket") || refresh_jsapi_ticket
    end
    
    def self.refresh_jsapi_ticket
      result = Typhoeus::Request.get("https://api.weixin.qq.com/cgi-bin/ticket/getticket?access_token=#{token}&type=jsapi")
      body = JSON.parse(result.body)
      $cache.set("wechat_jsapi_ticket", body['ticket'], expires_in: body['expires_in'].to_i)
      body['ticket']
    end

    def self.get_media_file_url(media_id)
      "http://file.api.weixin.qq.com/cgi-bin/media/get?access_token=#{token}&media_id=#{media_id}"
    end

  end
end
