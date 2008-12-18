require 'hpricot'
include Hpricot

# This class holds the contents of a MGF Transaction record.  It's normalized and made Ruby-esque.  
# There are also some convenience functions for importing different formats of XML that MGF sends us

module MobileGiving
class MgfTransaction

  attr_reader :campaign_id        
  attr_reader :carrier_id         
  attr_reader :donation_created_at
  attr_reader :donation_status    
  attr_reader :guid               
  attr_reader :keyword            
  attr_reader :phone_number       
  attr_reader :shortcode          
  attr_reader :transaction_id     
  attr_reader :mobile_messages

  # Use this when processing the XML response from query to the API (e.g. status(), which calls 'WebDonationStatusCheck'')
  def self.from_donation_status_get(xml)
    hash = Hash.from_xml(xml)["WebDonationStatusCheckResult"]
    return nil if !hash
    args = {
      :phone_number        => hash["MobileNumber"],
      :carrier_id          => hash["CarrierID"].to_i,
      :transaction_id      => hash["MobileTransactionID"].to_i,
      :guid                => hash["DonationMsgGUID"],
      :campaign_id         => hash["CampaignID"].to_i,
      :shortcode           => hash["ShortCode"],
      :donation_created_at => mgf_time_to_ruby_time(hash["MsgTime"]),
      :keyword             => hash["MessageText"],
      :donation_status     => hash["DonationStatus"]
    }
    MgfTransaction.new(args)
  end

  # Use this when processing the XML that is POSTed from MGF to a listener URL
  def self.from_donation_status_post(xml)
    hash = Hash.from_xml(xml)["GetDonationStatusResult"]
    return nil if !hash
    args = {
      :phone_number        => hash["MobileNumber"],
      :carrier_id          => hash["CarrierID"].to_i,
      :transaction_id      => hash["MobileTransactionID"].to_i,
      :guid                => hash["DonationMsgGUID"],
      :campaign_id         => hash["CampaignID"].to_i,
      :shortcode           => hash["ShortCode"],
      :donation_created_at => mgf_time_to_ruby_time(hash["MessageTime"]),
      :keyword             => hash["MessageText"],
      :donation_status     => hash["DonationStatus"]
    }
    MgfTransaction.new(args)
  end

  # given XML from MGF, return an array of zero or more mgf transactions 
  def self.from_transaction_set(xml)
    transactions = []
    transaction_array = [Hash.from_xml(xml)["TransactionSetResult"]["Transactions"].andand["MobileTransaction"]].flatten.compact
    transaction_array.each do |transaction|
      mobile_messages = [transaction["Messages"]["MobileMessage"]].flatten
      message = mobile_messages.first
      args = {
        :campaign_id         => message.andand["CampaignID"].andand.to_i,
        :shortcode           => message.andand["ShortCode"],
        :donation_status     => transaction["DonationStatus"],
        :donation_created_at => mgf_time_to_ruby_time(message.andand["MessageTime"]),
        :keyword             => message.andand["MessageText"],
        :transaction_id      => transaction["MobileTransactionID"].andand.to_i,
        :guid                => transaction["FirstMsgGUID"],
        :phone_number        => message.andand["MobileNumber"],
        :carrier_id          => message.andand["CarrierID"].andand.to_i,
        :mobile_messages     => [transaction["Messages"]["MobileMessage"]].flatten
      }
      transactions << MgfTransaction.new(args)
    end
    transactions
  end

  # the constructor takes a hash of args.  Usually calling from_transaction_set() or from_donation_status is what you want
  def initialize(args)
    @campaign_id         = args[:campaign_id]
    @shortcode           = args[:shortcode]
    @donation_status     = args[:donation_status]
    @keyword             = args[:keyword]
    @transaction_id      = args[:transaction_id]
    @guid                = args[:guid]
    @phone_number        = args[:phone_number]
    @carrier_id          = args[:carrier_id]
    @donation_created_at = args[:donation_created_at]
    @mobile_messages     = args[:mobile_messages]
  end

protected

  def self.mgf_time_to_ruby_time(time_str)
    Time.parse(time_str).utc if time_str
  end

end
end
