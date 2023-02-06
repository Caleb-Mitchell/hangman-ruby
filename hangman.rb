require "httparty"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

SECRET = SecureRandom.hex(32)
IMDB_API_KEY = ENV.fetch("IMDB_API_KEY", nil) if production?

configure do
  enable :sessions
  set :session_secret, SECRET
  set :erb, escape_html: true
end

ALPHA_LETTERS = %w(q w e r t y u i o p a s d f g h j k l z x c v b n m)
TOTAL_BODY_PARTS = 6
OFFICE_SEASON_COUNT = 9
SHOW_IMDB_ID = "tt0386676" # IMBD ID For: The Office
DEV = true if development?

helpers do
  def all_letters_found?
    @filtered_words.flatten.count do |letter|
      letter != "_"
    end == @filtered_words.flatten.size
  end

  def game_lost?
    @wrong_answer_count == TOTAL_BODY_PARTS
  end

  def game_over?
    @wrong_answer_count == TOTAL_BODY_PARTS || all_letters_found?
  end

  def display_definition
    session.delete(:episode_desc)
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

def set_episode
  episode = random_episode_test if DEV
  episode = random_episode_prod unless DEV

  if DEV
    session[:episode_desc] = episode["description"]
  else
    session[:episode_desc] = episode["plot"]
    session[:episode_img_path] = episode["image"]
  end
  session[:secret_word] = episode["title"].downcase
end

def reset_game
  set_episode
  session[:player_guesses] = []
  session[:available_letters] = ('a'..'z').to_a
  session[:wrong_answer_count] = 0
  session[:wrong_guess] = nil
end

def game_in_progress?
  session[:secret_word] && session[:episode_desc]
end

# free api has not limit on queries, but only has episodes from seaon 1
def random_episode_test
  HTTParty.get("https://officeapi.dev/api/episodes/random/")["data"]
end

def random_episode_prod
  random_season_num = (1..OFFICE_SEASON_COUNT).to_a.sample # not zero-indexed
  season = HTTParty.get(
    "https://imdb-api.com/en/API/SeasonEpisodes/#{IMDB_API_KEY}/#{SHOW_IMDB_ID}/#{random_season_num}",
    headers: { 'Content-Type' => 'application/json' }
  ).parsed_response

  random_season_num = season["episodes"].size
  season["episodes"][random_season_num - 1] # episodes are zero-indexed
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

  @img_path = session[:episode_img_path]
  @available_letters = session[:available_letters]
  @wrong_answer_count = session[:wrong_answer_count]

  erb :gallows
end

# Player guesses a letter
post '/gallows' do
  redirect '/welcome' unless session[:secret_word]

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
