require 'securerandom'
require 'sinatra'
require 'recurly'
require 'dotenv'
require 'json'

Dotenv.load

Recurly.subdomain = ENV['RECURLY_SUBDOMAIN']
Recurly.api_key = ENV['RECURLY_PRIVATE_KEY']

set :port, ENV['PORT']
set :public_folder, 'public'

enable :static
enable :logging

# New subscription
post '/api/subscriptions/new' do
  begin
    account_code = SecureRandom.uuid
    Recurly::Subscription.create!({
      plan_code: params['recurly-plan-code'],
      account: {
        account_code: account_code,
        billing_info: { token_id: params['recurly-token'] }
      }
    })
    redirect "/account/#{account_code}"
  rescue Recurly::Resource::Invalid, Recurly::API::ResponseError => e
    error(e)
  end
end

# Update subscription
post '/api/subscription' do
  begin
    subscription = Recurly::Subscription.find params['subscription']
    subscription.update_attributes! plan_code: params['plan']
    redirect "/account/#{subscription.account.account_code}"
  rescue Recurly::Resource::Invalid, Recurly::API::ResponseError => e
    error(e)
  end
end

# New account
post '/api/accounts/new' do
  begin
    Recurly::Account.create!({
      account_code: SecureRandom.uuid,
      billing_info: { token_id: params['recurly-token'] }
    })

    "Account created"
  rescue Recurly::Resource::Invalid, Recurly::API::ResponseError => e
    error(e)
  end
end

# Update account
put '/api/accounts/:account_code' do
  begin
    account = Recurly::Account.find params[:account_code]
    account.billing_info.token_id = params['recurly-token']
    account.save!

    "Account updated"
  rescue Recurly::Resource::Invalid, Recurly::API::ResponseError => e
    error(e)
  end
end

# Account management
get '/account/:code' do
  begin
    @account = Recurly::Account.find params['code']
    @plans = Recurly::Plan.all.map{|plan| {code: plan.plan_code, name: plan.name} }
    erb :account
  rescue Recurly::Resource::NotFound => e
    error(e)
  end
end

# Config conduit
get '/config.js' do
  content_type :js
  "window.recurlyConfig = { publicKey: '#{ENV['RECURLY_PUBLIC_KEY']}' }"
end

# Subscribe form
get '*' do
  send_file File.join(settings.public_folder, 'index.html')
end

# Generic error handling
def error e
  logger.error e
  status 402
  "An error occurred"
end
