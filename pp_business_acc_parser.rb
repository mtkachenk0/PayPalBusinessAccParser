#! /usr/bin/env ruby
require 'json'
require 'date'
require 'watir-webdriver'
require 'nokogiri'

# Overwritten built-in class Sting
# for Implementation of method i?
class String
  def i?
    /\A[-+]?\d+\z/ == self
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
    credentials = get_credentials
    @driver.text_field(name: 'login_email').set(credentials[:login])
    @driver.text_field(name: 'login_password').set(credentials[:password])
    @driver.send_keys(:enter)
    # this takes much time, really
    Watir::Wait.until(15) { logged_in? }
  end

  def logout
    @driver.element(xpath: '//*[@id="mer-header"]/div/div/div/div[4]/a').click
  end

  def parse_money_data
    @driver.goto('https://www.paypal.com/businessprofile/mymoney')
    Watir::Wait.until(10) { @driver.element(css: 'div#creditCards').present? }

    html = Nokogiri::HTML(@driver.html)
    credit_card = html.at_css('div#creditCards').at_css('div[class="unconfirm restricted"]')
    credit_card = credit_card.text.gsub("\u00A0", ' ').split
    balance, currency = pp_money_splitter(
      html.at_xpath('//*[@id="PPBalance"]/div[2]/text()').to_s
    )
    {
      card_number: credit_card[0],
      expires_at: credit_card[-1][0..-2],
      balance: balance,
      currency: currency
    }
  end

  def parse_account_data
    @driver.goto('https://www.paypal.com/businessprofile/settings/')
    # W8ing for JSON response
    Watir::Wait.until(10) { @driver.element(css: 'div#landingpage').present? }
    html = Nokogiri::HTML(@driver.html)
    json_data = html.at_css('div#landingpage').attribute('data-mybizinfo')
    data = JSON.parse(json_data, symbolize_names: true)
    {
      account_name: data[:primaryName][:fullName],
      email: data[:primaryEmail][:email],
      address: data[:primaryAddress],
      phone: data[:phones][0][:phoneString],
      account_type: data[:accountType],
      merchantId: data[:merchantId]
    }
  end

  def parse_transaction_data
    result = { transactions: [] }
    @driver.goto('https://www.paypal.com/businessexp/transactions')
    date_drop_down = @driver.element(:id, 'react-datepicker-dropdown-activityDateFilter-date-component')
    Watir::Wait.until(5) { date_drop_down.present? }
    date_drop_down.click
    # my 2016 year is full of transactions,
    # but available choices are [2017, 2016, 'Past 90 days', 'Past 30 days']
    date_choice = @driver.li(:text, '2016')
    sleep 1 # i don't know why, but the only sleep works here
    Watir::Wait.until(3) { date_choice.present? }
    date_choice.click
    Watir::Wait.until(10) { @driver.elements(xpath: '//*[@id="activity"]/table/tbody/tr/td') }
    sleep 5 # i don't know why, but the only sleep works here

    html = Nokogiri::HTML(@driver.html)
    transactions = html.css('tr[class~="activity-row primaryTxn"]')
    transactions.each do |transaction|
      money, currency = pp_money_splitter(transaction.at_css('td[class="price"]').text)
      result[:transactions].push(
        PayPalTransaction.new(
          transaction.at_css('td[class~="date"]').text,
          money,
          currency,
          transaction.at_css('td[class~="transactionStatus"]').text,
          transaction.at_css('td[class~="type"]').text << ' ' << transaction.at_css('span:nth-child(3)').text
        ).to_hash
      )
    end
    result
  end

  public

  def pp_money_splitter(balance)
    # money text should be presented as $<amount> <currency>
    balance = balance.gsub("\u00A0", ' ').split
    money = if balance[0][0].to_s.i?
              balance[0]
            # elsif balance[0][0].to_s.eql?('-')
            #   balance[0].to_s[2..-1]
            else
              balance[0].to_s[1..-1]
            end
    # rubocop said me not to use return, but how to
    # return 2 values at once?
    return money.gsub(',', '.'), balance[-1].to_s
  end

  def get_account_summary
    login
    account_data = Hash(nil)
    account_data.merge!(parse_account_data)
    account_data.merge!(parse_money_data)
    account_data.merge!(parse_transaction_data)
    logout
    @driver.close
    JSON.generate(accounts: [account_data])
  end
end

driver = PayPalDriver.new
puts driver.get_account_summary
gets.chomp
