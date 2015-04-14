Usage:

step1

copy all file t: /lib/weixin/




Setp2

add lines to: /config/weixin.rb

require 'tianji_wechat/tianji_wechat'
Rails.application.config.middleware.use TianjiWechat::Middleware, "tianji", "/weixin_secretary"
module TianjiWechat
  API = $conf[:weixin_secretary][:app_id]
  KEY = $conf[:weixin_secretary][:app_secret]
  FROM_USER = $conf[:weixin_secretary][:raw_id]
end

