require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

SECRET = SecureRandom.hex(32)

configure do
  enable :sessions
  set :session_secret, SECRET
  set :erb, escape_html: true
end

# TODO: I can make a grid of letters of the alphabet, and display for user
# choice when letters are clicked I can hide them with css

get '/' do
  erb :welcome
end

get '/empty_gallows' do
  erb :empty_gallows
end

get '/head_only' do
  erb :head_only
end

get '/head_and_body' do
  erb :head_and_body
end

get '/one_limb' do
  erb :one_limb
end

get '/two_limbs' do
  erb :two_limbs
end

get '/three_limbs' do
  erb :three_limbs
end

get '/full_body' do
  erb :full_body
end
