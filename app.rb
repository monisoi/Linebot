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

def get_weather_reply(message)
  message_list = message.split(' ')
  if message_list[0] != "トト"
    return
  end

  if message_list[1] == "天気"
    uri = URI.parse('http://weather.livedoor.com/forecast/webservice/json/v1?city=130010')
    json = Net::HTTP.get(uri)
    result = JSON.parse(json)
    today = {}
    result['forecasts'].each do |forecast|
        today = forecast if forecast['dateLabel'] == "今日"
    end

    weather = "今日の#{result['title']}は#{today['telop']}だぞ。"
    min_temp = ""
    if today['temperature']['min']
      min_temp = "#{today['temperature']['min']}℃"
    else
      min_temp = "知らん"
    end

    max_temp = ""
    if today['temperature']['max']
      max_temp = "#{today['temperature']['max']}℃"
    else
      max_temp = "知らん"
    end

    temperature = "最低気温は#{min_temp}。\n最高気温は#{max_temp}。"

    reply = "#{weather}\n#{temperature}"
    return reply
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