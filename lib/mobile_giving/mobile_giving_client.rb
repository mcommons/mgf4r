require 'hpricot'
include Hpricot

module MobileGiving
  class MobileGivingClient
  
    # API http://services.mobilegiving.org/Service.asmx

    # API status codes
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
    NUMBER_ALREADY_OPTED_IN       = 11  #not necessarily an error
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
    
    # Transaction Statuses
    MSG_SENT          = 'MsgSent'
    USER_ACCEPTED     = 'UserAccepted'
    BILLING_DECLINED  = 'BillingDeclined'
    DONATION_STATUSES = [ MSG_SENT, USER_ACCEPTED, BILLING_DECLINED ]
    
    # Default Settings
    HOSTNAME = 'services.mobilegiving.org'
    PATH     = '/Service.asmx'
    PORT     = 80
    
    def initialize(options={})
      @username = options[:username]
      @password = options[:password]
      @hostname = options[:hostname] || HOSTNAME
      @port     = options[:port]     || PORT
      @path     = options[:path]     || PATH
    end

    #answers the transaction_id or else raises
    def donate!(mobile_number, campaign_id, shortcode)        
      params = {
        :campaignID   => campaign_id.to_s, 
        :shortCode    => shortcode.to_s, 
        :mobileNumber => format_mobile_number(mobile_number)
      }.merge(credentials)

      http_response = post('WebDonation', params)
      validate_http_response( http_response )  #this raises for invalid responses
      process_web_donation_response( http_response.body )
    end

    # Answers the transaction status, or else raises
    def status( transaction_id )
      params = {
        :donationMsgGUID => transaction_id
      }.merge(credentials)

      http_response = post('WebDonationStatusCheck', params)
      validate_http_response( http_response )  #this raises for invalid responses
      process_web_donation_status_check_response( http_response.body )
    end
    
    # lists the transactions for a given campaign within a time range
    def transactions( campaign_id, start_time, end_time=Time.now.utc )
      params = {
        :campaignID => campaign_id.to_s, 
        :start      => format_time(start_time),
        :end        => format_time(end_time)
      }.merge(credentials)

      http_response = post('GetTransactionsDuring', params)
      validate_http_response( http_response )  #this raises for invalid responses
      process_get_transactions_during_response( http_response.body )
    end
    
    # this method is not yet tested :(
    def messages(transaction_id)
      params = {
        :donationMsgGUID => transaction_id
      }.merge(credentials)

      http_response = post('GetMessagesForTransaction', params)
      validate_http_response( http_response )  #this raises for invalid responses
      process_get_messages_for_transaction_response( http_response.body )
    end
    
  protected

    def credentials
      {:username=>@username, :password=>@password}
    end

    def format_mobile_number(mobile_number)
      digits_only = mobile_number.gsub(/[^\d]/,'')
      digits_only.size == 10 ? "1#{digits_only}" : digits_only.to_s
    end

    def format_time(time)
      time.strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    def post(function_name, post_params)
      Net::HTTP.new(@hostname, @port).start do |http|
        req = Net::HTTP::Post.new( path(function_name) )
        req.set_form_data(post_params)
        http.request( req ) 
      end
    end

    def path(function_name)
      "#{@path}/#{function_name}"
    end

    def process_web_donation_response( xml )
      process_response xml, "ServiceResult/ResultText"
    end

    def process_web_donation_status_check_response( xml )
      process_response xml, "WebDonationStatusCheckResult/DonationStatus"
    end

    def process_response(xml, xpath)
      doc = Hpricot.XML(xml)
      check_for_errors( doc )
      (doc/xpath).innerHTML
    end

    def process_get_transactions_during_response( xml )
      check_for_errors( Hpricot.XML(xml) )
      MgfTransaction.from_xml(xml)  #this will be an array of 0 or more mgf_transactions
    end

    def process_get_messages_for_transaction_response( xml )
      check_for_errors( Hpricot.XML(xml) )
      MgfTransaction.from_xml(xml)  #this will be an array of 0 or more mgf_transactions
    end

    def validate_http_response(res)
      if !res.kind_of?(Net::HTTPSuccess)
        raise "HTTP error posting to #{@hostname}: #{(res && res.code) || 'Nil response'}"
      end
    end

    def check_for_errors(doc)
      result_code = (doc/"ServiceResult/ResultCode").innerHTML
      return if result_code.to_i == SUCCESS

      result_text = (doc/"ServiceResult/ResultText").innerHTML
      case result_code.to_i
      when INVALID_CREDENTIALS 
        raise InvalidCredentialsException.new(result_text)
      when INVALID_CAMPAIGN, CARRIER_NOT_RUNNING_CAMPAIGN
        raise InvalidMgfCampaignException.new(result_text)
      when INVALID_PHONE_FORMAT, INVALID_AREA_CODE 
        raise InvalidPhoneFormatException.new(result_text)
      when INVALID_SHORTCODE   
        raise InvalidMgfShortcodeException.new(result_text)
      else
        raise MobileGivingException.new("Error accessing mobile giving API. resultCode=#{result_code}, resultText=#{result_text}")
      end
    end
    
  end


  class MgfTransaction

    # given XML from MGF, return an array of zero or more mgf transactions 
    def self.from_xml( xml )
      transactions = []
      transactions_hash = Hash.from_xml(xml)["TransactionSetResult"]["Transactions"]
      if transactions_hash
        (transactions_hash["MobileTransaction"]).each do |transaction_xml|
          transactions << MgfTransaction.new(transaction_xml)
        end
      end
      transactions
    end

    # the constructor takes a hash that has been generated from MGF XML.  Usually calling from_xml() is what you want
    def initialize(hash)
      @transaction=hash
    end

    def transaction_status
      @transaction["DonationStatus"]
    end

    def campaign_id
      message["CampaignID"].to_i if message && message["CampaignID"]      
    end

    def shortcode
      message["ShortCode"] if message
    end

    def transaction_id
      @transaction["MobileTransactionID"].to_i if @transaction["MobileTransactionID"]
    end

    def guid
      @transaction["FirstMsgGUID"]
    end

    def mobile_messages
      [@transaction["Messages"]["MobileMessage"]].flatten  #always put in an array, even if only one
    end

    def phone_number
      message["MobileNumber"] if message
    end
    
    def carrier_id
      message["CarrierID"].to_i if message && message["CarrierID"]
    end

    protected
    
    #most of the accessors can get info from any message in the collection; just pick the first one arbitrarily
    def message
      mobile_messages.first
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
  class InvalidPhoneFormatException < MobileGivingException
  end
  
  
end
