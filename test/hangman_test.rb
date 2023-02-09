require "simplecov"
SimpleCov.start

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "../hangman"

TEST_WORD = 'test'

class HangmanTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env['rack.session']
  end

  def create_test_guesses(num_guesses:, correct: true)
    guesses = []
    ('a'..'z').to_a.each do |letter|
      guesses << letter if correct && TEST_WORD.chars.include?(letter)
      guesses << letter if !correct && !TEST_WORD.chars.include?(letter)
      break if guesses.size == num_guesses
    end
    guesses
  end

  def session_test(lose: false, win: false)
    session = { 'rack.session' => { secret_word: TEST_WORD,
                                    episode_desc: 'test',
                                    player_guesses: [],
                                    available_letters: ('a'..'z').to_a,
                                    wrong_answer_count: 0,
                                    wrong_guess: nil } }
    session['rack.session'][:wrong_answer_count] = TOTAL_BODY_PARTS if lose
    session['rack.session'][:player_guesses] = TEST_WORD.chars if win
    session
  end

  def test_index
    get '/'
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/welcome'

    get '/welcome'
    assert_equal 200, last_response.status
    assert_includes last_response.body,
                    'Try to guess the <strong>title</strong>'
  end

  def test_start_button
    post '/welcome'
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/gallows'

    assert session[:wrong_guess].nil?
    assert !session[:secret_word].empty?, "There is no secret word assigned."
  end

  def test_start_button_prod
    ENV['RACK_ENV'] = 'prod_test'
    post '/welcome'
    assert_includes session[:episode_desc], 'basketball'
    assert_includes session[:secret_word], 'basketball'
    assert_equal "1", session[:season_num]
    assert_includes session[:episode_img_path], 'TFmYi00NWUzLWFlOWUtNW'
  end

  def test_gallows_invalid
    # get request to gallows without secret word or description causes redirect
    get '/gallows'
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/welcome'
  end

  def test_gallows_valid
    get '/gallows', {}, session_test
    assert_equal 200, last_response.status
    assert_includes last_response.body,
                    '<img src="/images/hangman_empty_gallows.svg"'
    assert_includes last_response.body,
                    '<section class="secret-letter-list">'
    assert_includes last_response.body,
                    '<section class="alpha-pick">'
  end

  def test_player_guess_invalid
    post '/gallows'
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/welcome'
  end

  def test_player_guess_valid
    post '/gallows', { letter_choice: 'a' }, session_test
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/gallows'
    assert_equal 1, session["wrong_answer_count"]
  end

  def test_player_guess_valid_and_present
    post '/gallows', { letter_choice: 'e' }, session_test
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/gallows'
    assert_nil session[:wrong_guess]
  end

  def test_show_incorrect_guess
    post '/gallows', { letter_choice: 'a' }, session_test

    get '/gallows'
    assert_includes last_response.body,
                    '<h4 class="wrong-letter">'
  end

  def test_player_two_guesses
    guesses = create_test_guesses(num_guesses: 2, correct: false)
    # test first guess with an empty test session
    post '/gallows', { letter_choice: guesses.first }, session_test

    # test another guess
    guesses[1..-1].each do |guess|
      post '/gallows', { letter_choice: guess }
    end
    assert_equal 2, session["wrong_answer_count"]
  end

  def test_player_three_guesses
    guesses = create_test_guesses(num_guesses: 3, correct: false)
    # test first guess with an empty test session
    post '/gallows', { letter_choice: guesses.first }, session_test

    # test remaining guesses
    guesses[1..-1].each do |guess|
      post '/gallows', { letter_choice: guess }
    end
    assert_equal 3, session["wrong_answer_count"]
  end

  def test_game_over_lose
    get '/gallows', {}, session_test(lose: true)
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<section class="episode-info">'
    assert_includes last_response.body, '<fieldset class="play-again">'
    assert_includes last_response.body,
                    '<img src="/images/hangman_full_body_lose.svg" ' \
                    'alt="full hangman body - player loses">'
  end

  def test_game_over_win
    get '/gallows', {}, session_test(win: true)
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<fieldset class="play-again">'
    assert_includes last_response.body, '<section class="episode-info">'
    assert_includes last_response.body,
                    '<img src="/images/hangman_full_body_win.svg" ' \
                    'alt="full hangman body - player wins!">'
  end

  def test_play_again_no
    post '/play_again', { play_again: 'no' }
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/welcome'
  end

  def test_play_again_yes_redirect
    post '/play_again', { play_again: 'yes' }
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/gallows'
  end

  def test_play_again_yes_reset
    post '/play_again', { play_again: 'yes' }
    assert_empty session[:player_guesses]
    assert_equal ('a'..'z').to_a, session["available_letters"]
    assert_equal 0, session[:wrong_answer_count]
    assert_nil session[:wrong_guess]
  end

  def test_play_again_no_redirect
    post '/play_again', { play_again: 'no' }
    assert_equal 302, last_response.status
    assert_includes last_response['Location'], '/welcome'
  end
end
