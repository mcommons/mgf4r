require 'hpricot'
include Hpricot

module MobileGiving
class MobileGivingClient

  # API http://services.mobilegiving.org/Service.asmx
  # web platform:  Extranet.mobilegiving.org

  #status codes
  SUCCESS                       = 0
  UNKNOWN_ERROR                 = -1  
  INVALID_CREDENTIALS           = 1
  INVALID_CAMPAIGN              = 2
  INVALID_PHONE_FORMAT          = 3
  INVALID_CARRIER               = 4   
  DATABASE_ERROR                = 5   
  INVALID_SHORTCODE             = 6
  INVALID_AREA_CODE             = 7   
  CAMPAIGN_COMPLETED            = 8   
  CARRIER_NOT_RUNNING_CAMPAIGN  = 9   
  NUMBER_NOT_FOUND              = 10  
  NUMBER_ALREADY_OPTED_IN       = 11  #not an error
  USER_NOT_OPTED_IN             = 1006
  UNABLE_TO_DETERMINE_CARRIER   = 1026
  NO_KEYWORD_FOUND_FOR_CAMPAIGN = 2001
  INVALID_CAMPAIGN_TYPE         = 3002
  CAMPAIGN_NOT_FOUND            = 5000
  CAMPAIGN_NOT_RUNNING          = 5001
  GUID_NOT_FOUND                = 6000
  USER_ALREADY_OPTED_IN         = 7000
  USER_ALREADY_OPTED_OUT        = 7001
  USER_NOT_FOUND_IN_CAMPAIGN    = 7002
  MESSAGE_LENGTH_EXCEEDED       = 7052
  
  MSG_SENT          = 'MsgSent'
  USER_ACCEPTED     = 'UserAccepted'
  BILLING_DECLINED  = 'BillingDeclined'
  DONATION_STATUSES = [ MSG_SENT, USER_ACCEPTED, BILLING_DECLINED ]
  
  #defaults
  HOSTNAME = 'services.mobilegiving.org'
  PATH = '/Service.asmx'
  
  def initialize(options={})
    @username = options[:username]
    @password = options[:password]
    @hostname = options[:hostname] || HOSTNAME
  end

  #answers the transaction_id or else raises
  def donate!(mobile_number, campaign_id, shortcode)        
    params = {
      :campaignID   =>campaign_id.to_s, 
      :shortCode    =>shortcode.to_s, 
      :mobileNumber =>format_mobile_number(mobile_number)
    }.merge(credentials)

    http_response = post('WebDonation', params)
    validate_http_response( http_response )  #this raises for invalid responses
    process_web_donation_response( http_response.body )
  end

  def status( guid )
    params = {
      :donationMsgGUID => guid
    }.merge(credentials)

    http_response = post('WebDonationStatusCheck', params)
    validate_http_response( http_response )  #this raises for invalid responses
    process_web_donation_status_check_response( http_response.body )
  end
  
  def transactions( campaign_id, start_time, end_time=Time.now.utc )
    params = {
      :campaignID => campaign_id.to_s, 
      :start      => start_time.to_s(:iso8601), 
      :end        => end_time.to_s(:iso8601)
    }.merge(credentials)

    http_response = post('GetTransactionsDuring', params)
    validate_http_response( http_response )  #this raises for invalid responses
    process_get_transactions_during_response( http_response.body )
  end
  
  def messages(guid)
    raise NotImplementedError
  end
  
protected

  def credentials
    {:username=>@username, :password=>@password}
  end

  def format_mobile_number mobile_number
    mobile_number.size == 10 ? "1#{mobile_number}" : mobile_number.to_s
  end

  def post(function_name, post_params)
    HttpUtil.do_post( @hostname, path(function_name), post_params )
  end
  
  def path(function_name)
    "#{PATH}/#{function_name}"
  end

  def process_web_donation_response( xml )
    process_response xml, "ServiceResult/ResultText"
  end

  def process_web_donation_status_check_response( xml )
    doc = Hpricot.XML(xml)
    check_for_errors( doc )
    MgfTransaction.from_donation_status_get(xml)  #this will be an array of 0 or more mgf_transactions
  end

  def process_response(xml, xpath)
    doc = Hpricot.XML(xml)
    check_for_errors( doc )
    (doc/xpath).innerHTML
  end

  def process_get_transactions_during_response( xml )
    doc = Hpricot.XML(xml)
    check_for_errors( doc )
    MgfTransaction.from_transaction_set(xml)  #this will be an array of 0 or more mgf_transactions
  end

  def validate_http_response(res)
    if !res.kind_of?(Net::HTTPSuccess)
      raise "HTTP error posting to #{@hostname}: #{res.andand.code || 'Nil response'}"
    end
  end

  def check_for_errors(doc)
    result_code = (doc/"ServiceResult/ResultCode").innerHTML
    return if result_code.to_i == SUCCESS

    result_text = (doc/"ServiceResult/ResultText").innerHTML
    case result_code.to_i
    when INVALID_CREDENTIALS 
      raise InvalidCredentialsException.new(result_text)
    when INVALID_CAMPAIGN,CARRIER_NOT_RUNNING_CAMPAIGN
      raise InvalidMgfCampaignException.new(result_text)
    when INVALID_PHONE_FORMAT, INVALID_AREA_CODE 
      raise InvalidPhoneFormatException.new(result_text)
    when INVALID_SHORTCODE   
      raise InvalidMgfShortcodeException.new(result_text)
    when CAMPAIGN_COMPLETED
      raise MgfCampaignNotRunningException.new(result_text)
    else
      raise MobileGivingException.new("Error accessing mobile giving API. resultCode=#{result_code}, resultText=#{result_text}")
    end
  end
  
end

class MobileGivingException < Exception
end
class InvalidCredentialsException < MobileGivingException
end
class InvalidMgfShortcodeException < MobileGivingException
end
class InvalidMgfCampaignException < MobileGivingException
end
class MgfCampaignNotRunningException < MobileGivingException
end
class InvalidPhoneFormatException < MobileGivingException
end


end
