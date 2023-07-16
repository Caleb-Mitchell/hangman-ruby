require "httparty"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

SECRET = SecureRandom.hex(32)
TMDB_API_KEY = ENV.fetch("TMDB_API_KEY", nil)

configure do
  enable :sessions
  set :session_secret, SECRET
  set :erb, escape_html: true
end

ALPHA_LETTERS = %w(q w e r t y u i o p a s d f g h j k l z x c v b n m)
TOTAL_BODY_PARTS = 6
OFFICE_SEASON_COUNT = 9
TMDB_SERIES_ID = "2316" # TMDB ID For: The Office

helpers do
  def all_letters_found?
    @filtered_words.flatten.count do |letter|
      letter != "_"
    end == @filtered_words.flatten.size
  end

  def game_over?
    @wrong_answer_count == TOTAL_BODY_PARTS || all_letters_found?
  end

  def display_description
    session.delete(:episode_desc)
  end

  def display_title
    session.delete(:secret_word).split.map(&:capitalize).join(" ")
  end
end

def hide_letters(letters_arr)
  letters_arr.map do |letter|
    if !letter.match?(/[a-z]/i) || session[:player_guesses].include?(letter)
      letter
    else
      "_"
    end
  end
end

def store_ep_details(episode)
  session[:episode_desc] = episode["overview"]
  session[:season_num] = episode["season_number"]
  session[:episode_img_path] = "http://image.tmdb.org/t/p/w500#{episode['still_path']}"
end

def set_episode
  case ENV.fetch("RACK_ENV", nil)
  when "test", "development"
    episode = episode_five_test
  when "production"
    episode = random_episode_prod
  end
  store_ep_details(episode)
  session[:secret_word] = episode["name"].downcase
end

def reset_game
  set_episode
  session[:player_guesses] = []
  session[:available_letters] = ('a'..'z').to_a
  session[:wrong_answer_count] = 0
  session[:wrong_guess] = nil
end

def game_in_progress?
  !session[:secret_word].nil? && !session[:episode_desc].nil?
end

def episode_five_test
  season = HTTParty.get(
    "https://api.themoviedb.org/3/tv/2316/season/1/episode/5",
    headers: { 'Content-Type' => 'application/json',
               'Authorization' => "Bearer #{TMDB_API_KEY}" }
  ).parsed_response
end

def random_episode_prod
  random_season_num = (1..OFFICE_SEASON_COUNT).to_a.sample # not zero-indexed
  season = HTTParty.get(
    "https://api.themoviedb.org/3/tv/#{TMDB_SERIES_ID}/season/#{random_season_num}",
    headers: { 'Content-Type' => 'application/json',
               'Authorization' => "Bearer #{TMDB_API_KEY}" }
  ).parsed_response

  season["episodes"].sample # episodes are zero-indexed
end

get '/' do
  redirect '/welcome'
end

# Welcome the user, say click to play
get '/welcome' do
  erb :welcome
end

# Create a hangman, and show empty gallows
post '/welcome' do
  reset_game

  redirect '/gallows'
end

# Show empty gallows, with underscores representing unguessed letters
get '/gallows' do
  redirect '/welcome' unless game_in_progress?

  @secret_word = session[:secret_word]

  @filtered_words = session[:secret_word].split.each_slice(2).map do |arr|
    arr.join(' ')
  end
  @filtered_words.map! { |word_group| hide_letters(word_group.chars) }

  @season_num = session[:season_num]
  @img_path = session[:episode_img_path]
  @available_letters = session[:available_letters]
  @wrong_answer_count = session[:wrong_answer_count]

  erb :gallows
end

# Player guesses a letter
post '/gallows' do
  redirect '/welcome' unless game_in_progress?

  session[:player_guesses] << params[:letter_choice]
  session[:available_letters].delete(params[:letter_choice])

  if session[:secret_word].chars.include?(params[:letter_choice])
    session[:wrong_guess] = nil
  else
    session[:wrong_answer_count] += 1
    session[:wrong_guess] = params[:letter_choice]
  end

  redirect '/gallows'
end

# Allow player to choose if they want to play again
post '/play_again' do
  redirect '/welcome' if params[:play_again] == "no"

  reset_game
  redirect '/gallows'
end
