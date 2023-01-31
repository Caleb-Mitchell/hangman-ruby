require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, SECRET
  set :erb, escape_html: true
end

# TODO: I can make a grid of letters of the alphabet, and display for user
# choice when letters are clicked I can hide them with css

get '/' do
  erb :empty_gallows
end
