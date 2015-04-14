# coding: utf-8
module TianjiWechat
  module RedPacket
    MCH_ID = "1233813302"
    HEADERS = { "Content-Type" => "application/xml",
                "charset" => "utf-8",
                "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" }
    if Rails.env.production?
      RootCA = '/tianji/web/file/weixin_pay_cert/rootca.pem'
      Cert   = '/tianji/web/file/weixin_pay_cert/apiclient_cert.pem'
      Key    = '/tianji/web/file/weixin_pay_cert/apiclient_key.pem'
    else
      RootCA = File.join( Rails.root, 'tmp', 'rootca.pem' )
      Cert   = File.join( Rails.root, 'tmp', 'apiclient_cert.pem' )
      Key    = File.join( Rails.root, 'tmp', 'apiclient_key.pem' )
    end

    def self.send(openid, amount, ip, opt={})
      url = "https://api.mch.weixin.qq.com/mmpaymkttransfers/sendredpack"
      xml_hash = {
        nonce_str: rand(10 ** 10).to_s,
        mch_id: MCH_ID,
        mch_billno: "#{MCH_ID}#{Time.now.strftime('%Y%m%d')}#{Time.now.to_i}",
        wxappid: 'wxe05d1fa4476be40a',
        nick_name: '天际小助手',
        send_name: '天际小助手',
        re_openid: openid,
        total_amount: amount,
        min_value: amount,
        max_value: amount,
        total_num: 1,
        wishing: '欢迎来好好约',
        client_ip: ip,
        act_name: '天际小助手',
        remark: '天际小助手'
      }
      xml_hash.merge!(sign: sign(xml_hash))
      xml = cdata_xml_from_hash(xml_hash)

      Typhoeus::Request.post( url, body: xml, headers: HEADERS,
                              #ssl_capath: RootCA, 
                              ssl_cert: Cert,
                              ssl_key: Key,
                              ssl_version: :CURL_SSLVERSION_TLSv1,
                              ssl_key_password: MCH_ID,
                              verbose: true )

    end

    def self.sign(params)
      string = params.sort.map{|k,v| "#{k.to_s}=#{v.to_s}"}.join("&")
      string = string + "&key=tianji01234567890123456789012345"
      Digest::MD5.hexdigest(string).upcase
    end

    def self.cdata_xml_from_hash(hash)
      builder = Nokogiri::XML::Builder.new do |xml|
         xml.xml{
           hash.each do |k, v|
             xml.send("#{k}") {xml.cdata(v)}
           end
         }
      end
      builder.to_xml
    end

  end
end
