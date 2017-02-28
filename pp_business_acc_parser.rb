#! /usr/bin/env ruby

require 'json'
require 'date'
require 'watir-webdriver'

class String
  def is_i?
    /\A[-+]?\d+\z/ === self
  end
end

class PayPalTransaction
  def initialize(date, amount, currency, status, description=nil)
    @date = Date.parse(date).iso8601
    @amount = amount
    @currency = currency
    @status = status
    @description = description
  end

  public
  def to_hash
    Hash[instance_variables.map { |name| [name[1..-1], instance_variable_get(name)] } ]
  end
end

class PayPalDriver

  def initialize(browser=:chrome, start_url='https://google.com')
    @driver = Watir::Browser.start(
        url=start_url,
        browser=browser
    )
    @driver.driver.manage.timeouts.implicit_wait = 5
    @is_logged_in = false
    @credentials = Hash.new(nil)
    @account_data = Hash.new(nil)
  end

  protected
  def get_credentials
    puts 'Please provide your login: '
    @credentials[:login] = gets.chomp
    puts 'Please provide your password: '
    @credentials[:password] = gets.chomp
  end

  def login
    @driver.goto('https://www.paypal.com/signin')
    if @credentials.values.empty?
      get_credentials
    end
    @driver.text_field(:name => 'login_email').set(@credentials[:login])
    @driver.text_field(:name => 'login_password').set(@credentials[:password])
    @driver.send_keys(:enter)

    begin
      Watir::Wait.until(10) {@driver.title.start_with?('Log')}
    rescue Watir::Wait::TimeoutError => ex
      puts ex.to_s
    ensure
      @is_logged_in = self.logged_in?
    end
  end

  def logged_in?
    !@driver.text_field(:name => 'login_email').exists?
  end

  def go2summary
    begin
      @driver.element(:xpath => '//*[@id="mer-header"]/div/div/a[2]').when_present(5).click
      puts "Clicked to Summary \n"
    rescue Watir::Exception => ex
      puts "Unexpected exception: #{ex}"
    ensure
      return @driver.title.start_with?('Summary')
    end
  end

  def go2profile_options
    if @driver.title.eql?('My Profile - PayPal')
      return true
    end
    profile_button = @driver.div(:class=>'mer-settings-wrapper')
    until profile_button.exists? do sleep 1 end

    begin
      profile_button.when_present(timeout=10).click
      puts 'Clicked'
    rescue Watir::Exception::UnknownObjectException => ex
      $stderr.print "Caught exception. #{ex.to_s}"
    else
      return @driver.title.eql?('My Profile - PayPal')
    end
  end

  def get_money_related_data
    begin
      @driver.element(:id => 'mymoney').click
    rescue Watir::Exception => ex
      puts "All right, most probably button is already pressed,\n #{ex}"
    end
    # Returns balance and currency
    card_data = @driver.element(:xpath => '//*[@id="creditCards"]/div[2]').text.split
    @account_data[:card_number], @account_data[:expires_at] = card_data[0].to_s, card_data[-1].to_s[0..-2]
    @account_data[:balance], @account_data[:currency] = pp_money_splitter(
        @driver.element(:xpath => '//*[@id="PPBalance"]/div[2]').text
    )
    #balance_data[0].to_s[1..-1], balance_data[-1].to_s
    @account_data
  end

  def get_base_account_data
    begin
      @driver.element(:id => 'mybizinfo').click
    rescue Watir::Exception => ex
      puts "All right, most probably button is already pressed,\n #{ex}"
    ensure
      {:account_name => '//*[@id="name"]/div[2]',
       :email => '//*[@id="Emails"]/li',
       :phone => '//*[@id="Phones"]/li[1]/span[1]',
       :merchant_id => '//*[@id="merchantId"]/div[2]'
      }.each_pair do |name, xpath|
        begin
          @account_data[name] = @driver.element(
              :xpath => xpath
          ).text
        rescue Watir::Exception::UnknownObjectException => ex
          puts "Cannot get data for #{name} due to #{ex}"
        end
      end
      if @account_data.has_key?(:email)
        # it's stored like <some_email> Primary
        @account_data[:email] = @account_data[:email].split[0]
      end
    end
  @account_data
  end

  def get_transactions_data
    @account_data[:transactions] = []

    begin
      @driver.element(:xpath => '//*[@id="activity-tile"]/div[3]/div/a').when_present(5).click
    rescue Watir::Exception::TimeoutError => ex
      puts "All right, most probably button does not exist,\n #{ex}"
    end
    # please forgive me, I select last 90 days, because I don't want to play with PayPal's calendar
    # if it's critical - notify me, I'll do ;)
    begin
      @driver.element(:id, 'react-datepicker-dropdown-activityDateFilter-date-component').click
      sleep 1
      @driver.li(:text, '2016').click #'Past 90 days').click
    rescue Watir::Exception => ex
      puts ex
    end
    transactions = @driver.elements(:xpath => '//*[@id="activity"]/table/tbody/tr')
    Watir::Wait.until(10) {transactions}
    transactions.each do |raw|
      if raw.attribute_value(:class).start_with?('activity-row primaryTxn')
        # print raw.text
        # puts "\n"
        # print raw.text.split("\n")
        money, currency = self.pp_money_splitter(raw.element(:class => 'price').text)
        puts money, currency
        @account_data[:transactions].push(PayPalTransaction.new(
            date=raw.element(:class => 'date-time').text,
            amount=money,
            currency=currency,
            status=raw.element(:class => 'transactionStatus').text,
            description=raw.element(:class => 'type').text << ' ' << raw.element(:class => 'desc').text
        ).to_hash)
      end
    end
  end

  public
  def pp_money_splitter(money_text)
    # money text should be presented as $<amount> <currency>
    money_text = money_text.split
    if money_text[0][0].to_s.is_i?
      money = money_text[0]
    elsif money_text[0][0].to_s.eql?('-')
      money = money_text[0].to_s[2..-1]
    else
      money = money_text[0].to_s[1..-1]
    end
    return money.gsub!(',', '.'), money_text[-1].to_s
  end

  def to_json
    JSON.generate({:accounts=> [@account_data]})
  end

  #{
  #    "accounts":[
  #    {
  #        "account_name":"Maxim Tcacenco",
  #        "email":"tkacenko.maxim@gmail.com",
  #        "phone":"+373 60022021",
  #        "merchant_id":"QSKXK5PSPGPLL",
  #        "card_number":"x-1234",
  #        "expires_at":"7/2019",
  #        "balance":"103.48",
  #        "currency":"USD",
  #        "transactions":[
  #          {
  #            "date":"2016-12-09",
  #            "amount":"12.30",
  #            "currency":"USD",
  #            "status":"Completed",
  #            "description":"Refund from  BuyinCoins Inc"
  #    }]
  #  }]
  #}
  def get_account_info
    # 3 attempts to login, (sometimes it doesn't work)
    [0..3].each do
      print 'Trying to login'
      if self.login
        break
      end
    end
    self.go2profile_options
    self.get_base_account_data
    self.get_money_related_data
    self.go2summary
    self.get_transactions_data
    self.to_json
  end

end

driver = PayPalDriver.new
puts driver.get_account_info
gets.chomp