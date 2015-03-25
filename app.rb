require 'securerandom'
require 'sinatra'
require 'recurly'
require 'dotenv'

Dotenv.load

Recurly.subdomain = ENV['RECURLY_SUBDOMAIN']
Recurly.api_key = ENV['RECURLY_PRIVATE_KEY']

set :port, ENV['PORT']
set :public_folder, 'public'

enable :static
enable :logging

post '/subscriptions/new' do
  begin
    Recurly::Subscription.create!({
      plan_code: ENV['RECURLY_PLAN_CODES'],
      account: {
        account_code: SecureRandom.uuid,
        billing_info: { token_id: params['recurly-token'] }
      }
    })

    "Subscription created"
  rescue Recurly::Resource::Invalid, Recurly::API::ResponseError => e
    error(e)
  end
end

post '/accounts/new' do
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

put '/accounts/:account_code' do
  begin
    account = Recurly::Account.find params[:account_code]
    account.billing_info.token_id = params['recurly-token']
    account.save!

    "Account updated"
  rescue Recurly::Resource::Invalid, Recurly::API::ResponseError => e
    error(e)
  end
end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/config.js' do
  "window.recurlyPublicKey = '#{ENV['RECURLY_PUBLIC_KEY']}'"
end

def error e
  logger.error e
  status 402
  "An error occurred"
end
