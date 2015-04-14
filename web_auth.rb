module TianjiWechat
  module WebAuth
    def self.get_redirect_url(state)
      if state.match(/SPLIT/)
        if state.split("SPLIT")[0] == "position"
          "http://job.tianji.com/career/position/#{state.split("SPLIT")[1]}"
        else
          "http://www.tianji.com/#{state.split("SPLIT")[0]}/#{state.split("SPLIT")[1]}"
        end
      else
        url_map = { "profile" => "http://www.tianji.com/p",
                    "hr" => "http://www.tianji.com/hr",
                    "ceWebapp" => "http://www.tianji.com/ce/webapp",
                    "jobIntention" => "http://job.tianji.com/career/intention",
                    "index" => "http://www.tianji.com",
                    "perfectWorkExperience" => "http://www.tianji.com/p/work_experiences/new",
                    "pymk" => "http://www.tianji.com/contacts/pymk" }
        url_map[state]
      end
    end

    def self.generate_web_auth_url(state)
      "https://open.weixin.qq.com/connect/oauth2/authorize?appid=#{TianjiWechat::API}&redirect_uri=http%3A%2F%2F#{$conf[:weixin_secretary][:domain]}.tianji.com%2Fweixin_secretary%2Fweb_auth&response_type=code&scope=snsapi_base&state=#{state}#wechat_redirect"
    end

    def self.get_auto_login_url(account, redirect_url)
      "#{$email_conf[:auto_reconnect_base_url]}mtrck=#{Tianji::MailService.login_token(:weixin_secretary, account)}&#{{service: redirect_url}.to_query}"
    end

    def self.auth(code)
      result = Typhoeus::Request.get("https://api.weixin.qq.com/sns/oauth2/access_token?appid=#{TianjiWechat::API}&secret=#{TianjiWechat::KEY}&code=#{code}&grant_type=authorization_code")
      JSON.parse(result.body)
    end

  end
end
