module MobileGiving

describe MobileGivingClient, "making HTTP posts" do

  before(:each) do
    @client = MobileGivingClient.new
    @response = Net::HTTPForbidden.new(nil,nil,nil)
    @client.stub!(:post).and_return(@response)
  end

  it "should handle unsuccessful HTTP requests properly" do
    @response.should_not_receive(:body)
    lambda {
      @client.donate!(nil, nil, nil)    
    }.should raise_error
  end
end

describe MobileGivingClient do

  before(:each) do
    @mobile_number = "15551231234"
    @campaign_id   = "123"
    @shortcode     = "12345"

    @client = MobileGivingClient.new

    @response = Net::HTTPSuccess.new(nil,nil,nil)
    @client.stub!(:post).and_return(@response)

  end

  describe "error states" do
    it "should properly raise if credentials are wrong" do
      @response.stub!(:body).and_return invalid_credentials_xml
      lambda {
        @client.donate!(@mobile_number, @campaign_id, @shortcode)
      }.should_raise InvalidCredentialsException
    end

    protected
    
    def invalid_credentials_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <ServiceResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>1</ResultCode>
        <ResultText>Incorrect Username or Password</ResultText>
        <RecordID>0</RecordID>
      </ServiceResult>"
    end

  end

  describe "making donations" do
    it "should properly post donations to their REST api" do
      @response.stub!(:body).and_return successful_donation_xml
      @client.donate!(@mobile_number, @campaign_id, @shortcode).should == "2fd7f7e0-8dd4-4e07-80a3-4bc95e73f267"
    end

    it "should properly raise if campaign is wrong" do
      @response.stub!(:body).and_return invalid_campaign_xml
      lambda {
        @client.donate!(@mobile_number, @campaign_id, @shortcode)
      }.should_raise InvalidMgfCampaignException
    end

    it "should properly raise if shortcode is wrong" do
      @response.stub!(:body).and_return invalid_shortcode_xml
      lambda {
        @client.donate!(@mobile_number, @campaign_id, @shortcode)
      }.should_raise InvalidMgfShortcodeException
    end

    it "should properly raise if phone format is wrong" do
      @response.stub!(:body).and_return invalid_phone_format_xml
      lambda {
        @client.donate!(@mobile_number, @campaign_id, @shortcode)
      }.should_raise InvalidPhoneFormatException
    end

    protected

    def successful_donation_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <ServiceResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>0</ResultCode>
        <ResultText>2fd7f7e0-8dd4-4e07-80a3-4bc95e73f267</ResultText>
        <RecordID>0</RecordID>
      </ServiceResult>"
    end

    def invalid_campaign_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <ServiceResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>2</ResultCode>
        <ResultText>Invalid CampaignID</ResultText>
        <RecordID>0</RecordID>
      </ServiceResult>"
    end

    def invalid_shortcode_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <ServiceResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>6</ResultCode>
        <ResultText>Invalid ShortCode</ResultText>
        <RecordID>0</RecordID>
      </ServiceResult>"
    end

    def invalid_phone_format_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <ServiceResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>3</ResultCode>
        <ResultText>Incorrect Cell Phone Number Format</ResultText>
        <RecordID>0</RecordID>
      </ServiceResult>"
    end

  end
  
  describe "querying for transactions in a time range" do
    def transactions_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <TransactionSetResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>0</ResultCode>
        <ResultText>Success</ResultText>
        <RecordID>0</RecordID>
        <Transactions>
          <MobileTransaction>
            <FirstMsgGUID>a325b27f-e91c-49a5-b21d-a195e2e3b940</FirstMsgGUID>
            <MobileTransactionID>954706</MobileTransactionID>
            <DonationStatus>MsgSent</DonationStatus>
            <Messages>
              <MobileMessage>
                <MobileMessageID>8185119</MobileMessageID>
                <CampaignID>1234</CampaignID>
                <ShortCode>12345</ShortCode>
                <MessageTime>2008-10-27T10:37:48</MessageTime>
                <CarrierID>31002</CarrierID>
                <CarrierName>AT&amp;T Wireless</CarrierName>
                <MobileBilledAmount>0.0000</MobileBilledAmount>
                <MessageText>work</MessageText>
                <MobileTransactionID>954706</MobileTransactionID>
                <MobileNumber>15551231234</MobileNumber>
                <MessageGUID>a325b27f-e91c-49a5-b21d-a195e2e3b940</MessageGUID>
              </MobileMessage>
              <MobileMessage>
                <MobileMessageID>8185120</MobileMessageID>
                <CampaignID>1234</CampaignID>
                <ShortCode>12345</ShortCode>
                <MessageTime>2008-10-27T10:37:48</MessageTime>
                <CarrierID>31002</CarrierID>
                <CarrierName>AT&amp;T Wireless</CarrierName>
                <MobileBilledAmount>0.0000</MobileBilledAmount>
                <MessageText>Thanks! $5 charged to your phone bill.Txt work up to 5x for TNPO donations. Info?Visit hmgf.org/T or txt HELP.STOP to cancel. Other charges may apply</MessageText>
                <MobileTransactionID>954706</MobileTransactionID>
                <MobileNumber>15551231234</MobileNumber>
                <MessageGUID>a325b27f-e91c-49a5-b21d-a195e2e3b940</MessageGUID>
              </MobileMessage>
            </Messages>
          </MobileTransaction>
          <MobileTransaction>
            <FirstMsgGUID>ff0f5d43-32c9-4021-9921-e963cb794fbf</FirstMsgGUID>
            <MobileTransactionID>954768</MobileTransactionID>
            <DonationStatus>MsgSent</DonationStatus>
            <Messages>
              <MobileMessage>
                <MobileMessageID>8185223</MobileMessageID>
                <CampaignID>1234</CampaignID>
                <ShortCode>12345</ShortCode>
                <MessageTime>2008-10-27T11:15:25</MessageTime>
                <CarrierID>31002</CarrierID>
                <CarrierName>AT&amp;T Wireless</CarrierName>
                <MobileBilledAmount>0.0000</MobileBilledAmount>
                <MessageText>work</MessageText>
                <MobileTransactionID>954768</MobileTransactionID>
                <MobileNumber>15551231234</MobileNumber>
                <MessageGUID>ff0f5d43-32c9-4021-9921-e963cb794fbf</MessageGUID>
              </MobileMessage>
            </Messages>
          </MobileTransaction>
        </Transactions>
      </TransactionSetResult>"
    end

    def no_transactions_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <TransactionSetResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>0</ResultCode>
        <ResultText>Success</ResultText>
        <RecordID>0</RecordID>
        <Transactions />
      </TransactionSetResult>"
    end
    
    it "should have all the transactions listed in a valid hash" do
      @response.stub!(:body).and_return transactions_xml
      @client.transactions(@campaign_id, 1.day.ago).size.should == 2
    end

    it "should gracefully handle no transactions" do
      @response.stub!(:body).and_return no_transactions_xml
      @client.transactions(@campaign_id, 1.second.ago).size == 0      
    end
    
    it "should handle invalid date ranges" do
      @response.stub!(:body).and_return no_transactions_xml
      @client.transactions(@campaign_id, 1.year.from_now, 1.year.ago).size == 0      
    end
    
    it "should contain a collection of associated mobile messages" do
      @response.stub!(:body).and_return transactions_xml
      @client.transactions(@campaign_id, 1.day.ago).first.mobile_messages.size.should == 2
    end

    describe MgfTransaction do

      before(:each) do
        @response.stub!(:body).and_return transactions_xml
        @transactions = @client.transactions(@campaign_id, 1.day.ago)
        @t1 = @transactions.first
      end

      it "should have an associated guid" do
        @t1.guid.should == "a325b27f-e91c-49a5-b21d-a195e2e3b940"
      end
    
      it "should have an array of mobile messages, even if there is only one message" do
         @transactions[0].mobile_messages.class.should == Array
         @transactions[1].mobile_messages.class.should == Array
      end

      it "should have a transaction ID" do
        @t1.transaction_id.should == 954706
      end
      
      it "should have a campaign ID" do
        @t1.campaign_id.should == 1234
      end
      
      it "should have a shortcode" do
        @t1.shortcode.should == '12345'
      end
      
      it "should have a phone number" do
        @t1.phone_number.should == '15551231234'
      end
      
      it "should have a carrier" do
        @t1.carrier_id.should == 31002
      end

    end    
  end
  

  describe "querying for transaction status" do
    it "should have the proper state for a pending donation" do
      @response.stub!(:body).and_return pending_transaction_status_xml
      @client.status("2fd7f7e0-8dd4-4e07-80a3-4bc95e73f267").should == "MsgSent"
    end

    it "should have an Unknown state for an invalid transcation ID" do
      @response.stub!(:body).and_return unknown_transaction_xml
      @client.status(123).should == "Unknown"
    end

    protected

    def pending_transaction_status_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <WebDonationStatusCheckResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>0</ResultCode>
        <ResultText>Success</ResultText>
        <RecordID>0</RecordID>
        <MobileNumber>15551231234</MobileNumber>
        <CarrierID>31002</CarrierID>
        <CarrierName>AT&amp;T Wireless</CarrierName>
        <DonationStatus>MsgSent</DonationStatus>
        <MobileTransactionID>959798</MobileTransactionID>
        <DonationMsgGUID>2fd7f7e0-8dd4-4e07-80a3-4bc95e73f267</DonationMsgGUID>
        </WebDonationStatusCheckResult>"
    end

    def unknown_transaction_xml
      "<?xml version=\"1.0\" encoding=\"utf-8\"?>
      <WebDonationStatusCheckResult xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://services.mobilegiving.org\">
        <ResultCode>0</ResultCode>
        <ResultText>Success</ResultText>
        <RecordID>0</RecordID>
        <CarrierID>0</CarrierID>
        <DonationStatus>Unknown</DonationStatus>
        <DonationMsgGUID>1</DonationMsgGUID>
      </WebDonationStatusCheckResult>"  
    end


  end
  
end

end
