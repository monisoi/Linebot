require 'sinatra'
require 'line/bot'
require 'net/http'
require 'uri'
require 'json'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
end

def get_weather_reply(word)
  if word == "天気"
    uri = URI.parse('http://weather.livedoor.com/forecast/webservice/json/v1?city=130010')
    json = Net::HTTP.get(uri)
    result = JSON.parse(json)
    today = result[0]
    return "今日の#{result['today']}は#{today['telop']}だぞ。"
  end
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        message = {
          type: 'text',
          text: get_weather_reply(event.message['text'])
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

  "OK"
end