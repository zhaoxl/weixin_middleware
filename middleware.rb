module TianjiWechat
  #微信中间件
  class Middleware
    def initialize(app, token, path)
      @app = app
      @app_token = token
      @path = path
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      #只有路径是指定的路径才进入处理
      if @path == env['PATH_INFO'].to_s && ['GET', 'POST'].include?(env['REQUEST_METHOD'])
        request = Rack::Request.new(env)
        #验证服务器请求
        return invalid_request! unless request_is_valid?(@app_token, request.params)
        return [
          200,
          { 'Content-type' => 'text/plain', 'Content-length' => request.params['echostr'].length.to_s },
          [ request.params['echostr'] ]
        ] if request.get?
        raw_msg = env["rack.input"].read
        begin
          #创建消息对象
          msg = TianjiWechat::Message.factory(raw_msg)
          #把对象推入到env中，以便controller中获取
          env.update "weixin.msg" => msg, "weixin.msg.raw" => raw_msg
          Log.info("Middleware.call Weixin call server") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_USER
            log.state = WeixinLog::STATE_OK
            log.to_user = msg.ToUserName
            log.from_user = msg.FromUserName
            log.timestamp = msg.CreateTime
            log.message_type = msg.MsgType
            log.message_content = raw_msg
            log.exception_content = nil
            log.error_code = nil
          end
          @app.call(env)
        rescue MessageParsingException => ex
          Log.info("Middleware.call Weixin call server. message parsing error: #{ex.to_s}") do |log|
            log.user_id = nil
            log.log_type = WeixinLog::TYPE_USER
            log.state = WeixinLog::STATE_EXCEPTION
            log.to_user = nil
            log.from_user = nil
            log.timestamp = nil
            log.message_type = nil
            log.message_content = raw_msg
            log.exception_content = ex.to_s
            log.error_code = nil
          end
          return [500, { 'Content-type' => 'text/html' }, ["Message parsing error: #{ex.to_s}"]]
        end
      else
        @app.call(env)
      end
    end
            
    #服务器回调验证
    def request_is_valid?(app_token, params)
      #开发模式默认通过验证
      if Rails.env.development?
        Log.info("Middleware.request_is_valid current is a development environment default return true")
        Log.info("Middleware.request_is_valid success")
        return true
      end
      begin
        param_array = [app_token, params['timestamp'], params['nonce']]
        sign = Digest::SHA1.hexdigest(param_array.sort.join)
        result = sign == params['signature']
        if result
          Log.info("Middleware request_is_valid success")
        else
          Log.info("Middleware request_is_valid failed")
        end
        return result
      rescue Exception => ex
        exception_msg = <<-STR
          Middleware.request_is_valid exception>>>>>>>>>>>>>>>>>>>>
          #{ex.message}
          #{ex.backtrace}
        STR
        ::TianjiWechat::Log.info(exception_msg)
      end
      return false
    end
    
    #验证失败返回401错误码
    def invalid_request!
      [401, { 'Content-type' => 'text/html'}, ["verification invalid"]]
    end 
  end
  
end