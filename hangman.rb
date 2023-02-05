require "httparty"
require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"

SECRET = SecureRandom.hex(32)

configure do
  enable :sessions
  set :session_secret, SECRET
  set :erb, escape_html: true
end

ALPHA_LETTERS = ('a'..'z').to_a
TOTAL_BODY_PARTS = 6

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
  episode = random_episode
  session[:secret_word] = episode["data"]["title"].downcase
  session[:episode_desc] = episode["data"]["description"]
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

def random_episode
  HTTParty.get("https://officeapi.dev/api/episodes/random/")
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
