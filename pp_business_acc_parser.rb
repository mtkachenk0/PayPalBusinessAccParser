#! /usr/bin/env ruby
require 'json'
require 'date'
require 'watir-webdriver'

# Overwritten built-in class Sting
# for Implementation of method i?
class String
  def i?
    /\A[-+]?\d+\z/ == self # === vs == ?
  end
end

# PayPalTransaction object
class PayPalTransaction
  def initialize(date, amount, currency, status, description = nil)
    @date = Date.parse(date).iso8601
    @amount = amount
    @currency = currency
    @status = status
    @description = description
  end

  def to_hash
    Hash[instance_variables.map { |name| [name[1..-1], instance_variable_get(name)] }]
  end
end

# Main class that contains all necessary methods
# to provide solution for test task
class PayPalDriver
  def initialize(browser = :chrome, start_url = 'https://google.com')
    @driver = Watir::Browser.start(start_url, browser)
    @driver.driver.manage.timeouts.implicit_wait = 5
  end

  protected

  def get_credentials
    credentials = Hash.new(nil)
    # In python I'd use generator function for this case
    puts 'Please provide your login: '
    credentials[:login] = gets.chomp
    puts 'Please provide your password: '
    credentials[:password] = gets.chomp
    credentials
  end

  def logged_in?
    !@driver.text_field(name: 'login_email').exists?
  end

  def login
    @driver.goto('https://www.paypal.com/signin')
    @credentials = get_credentials
    @driver.text_field(name: 'login_email').set(@credentials[:login])
    @driver.text_field(name: 'login_password').set(@credentials[:password])
    @driver.send_keys(:enter)
    Watir::Wait.until(15) { @driver.title.start_with?('Summary') }
    end

  def go2summary
    return true if @driver.title.start_with?('Summary')
    summary_button = @driver.element(xpath: '//*[@id="mer-header"]/div/div/a[2]')
    until summary_button.exists? do sleep 1 end
    summary_button.when_present(10).click
    puts "Gone to Summary \n"
    page_changed = @driver.title.start_with?('Summary')
    Watir::Wait.until(10) { page_changed }
    page_changed
  end

  def go2profile_options
    return true if @driver.title.start_with?('My Profile')
    profile_button = @driver.div(class: 'mer-settings-wrapper')
    until profile_button.exists? do sleep 1 end
    profile_button.when_present(10).click
    puts "Gone to Profile Options\n"
    page_changed = @driver.title.start_with?('My Profile')
    Watir::Wait.until(10) { page_changed }
    page_changed
  end

  def update_with_money_data(account_data)
    begin
      @driver.element(id: 'mymoney').click
    rescue Watir::Exception => ex
      # Everything is ok, most probably button is already pressed
      puts ex
    end
    card_data = @driver.element(xpath: '//*[@id="creditCards"]/div[2]').text.split
    # do not use parallel assignment !
    account_data[:card_number] = card_data[0].to_s
    account_data[:expires_at] = card_data[-1].to_s[0..-2]
    # parallel assignment again, but it's useful
    # 'cause pp_money_splitter returns 2 values
    account_data[:balance], account_data[:currency] = pp_money_splitter(
        @driver.element(xpath: '//*[@id="PPBalance"]/div[2]').text
    )
    account_data
  end

  def update_with_account_data(account_data)
    begin
      @driver.element(id: 'mybizinfo').click
    rescue Watir::Exception => ex
      # Everything is ok, most probably button is already pressed
      puts ex
    xpath_map = {
          account_name: '//*[@id="name"]/div[2]',
          email: '//*[@id="Emails"]/li',
          phone: '//*[@id="Phones"]/li[1]/span[1]',
          merchant_id: '//*[@id="merchantId"]/div[2]'
      }
    fails = 0
    xpath_map.each_pair do |name, xpath|
      begin
        account_data[name] = @driver.element(xpath: xpath).text
      rescue Watir::Exception::UnknownObjectException => ex
        fails += 1
        puts "Cannot get data for #{name} due to #{ex}"
      end
    end
    account_data[:email] = account_data[:email].split[0] if account_data.key?(:email)
    raise RuntimeError('Smth went wrong') if fails.eql?(xpath_map.keys.length)
    end
    account_data
  end

  def update_with_transactions_data(account_data)
    account_data[:transactions] = []

    begin
      @driver.element(xpath: '//*[@id="activity-tile"]/div[3]/div/a').when_present(5).click
    rescue Watir::Exception::TimeoutError => ex
      puts "All right, most probably button does not exist,\n #{ex}"
    end
    # please forgive me, I select last 90 days,
    # because I don't want to play with PayPal's calendar
    # if it's critical - notify me, I'll do ;)
    begin
      @driver.element(:id, 'react-datepicker-dropdown-activityDateFilter-date-component').click
      sleep 1
      @driver.li(:text, 'Past 90 days').click # '2016').click @mtkachenko testing
    rescue Watir::Exception => ex
      puts ex
    end
    transactions = @driver.elements(xpath: '//*[@id="activity"]/table/tbody/tr')
    Watir::Wait.until(10) { transactions }
    transactions.each do |raw|
      if raw.attribute_value(:class).start_with?('activity-row primaryTxn')
        money, currency = pp_money_splitter(raw.element(class: 'price').text)
        account_data[:transactions].push(
            PayPalTransaction.new(
                raw.element(class: 'date-time').text,
                money,
                currency,
                raw.element(class: 'transactionStatus').text,
                raw.element(class: 'type').text << ' ' << raw.element(class: 'desc').text
            ).to_hash
        )
      end
    end
  end

  public

  def pp_money_splitter(balance)
    puts balance
    # money text should be presented as $<amount> <currency>
    balance = balance.split
    money = if balance[0][0].to_s.i?
              balance[0]
            elsif balance[0][0].to_s.eql?('-')
              balance[0].to_s[2..-1]
            else
              balance[0].to_s[1..-1]
            end
    # rubocop said me not to use return, but how to
    # return 2 values at once?

    return money.gsub!(',', '.'), balance[-1].to_s
  end

  # {
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
  # }
  def summarise_account_data
    # 3 attempts to login, (sometimes it doesn't work)
    [0..3].each do
      print 'Trying to login'
      login && break # means <break if login>
    end
    account_data = Hash(nil)
    go2profile_options
    update_with_account_data(account_data)
    update_with_money_data(account_data)
    go2summary
    update_with_transactions_data(account_data)

    JSON.generate(accounts: [account_data])
  end
end

driver = PayPalDriver.new
puts driver.summarise_account_data
gets.chomp
