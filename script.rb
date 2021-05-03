require 'open-uri'
require 'nokogiri'
require 'csv'
require 'telegram/bot'

token = '927181166:AAEgY2qml7YsoXveofAVdLPipJl1M3V8_0s'

def get_brand_path(brand)
  brand.upcase!
  brand_element = Nokogiri::HTML.parse(open('https://monro24.ru/brand.php'))
                            .css('.brands-guide__list li a')
                            .select { |item| item.text.upcase.include? brand }
                            .first

  if brand_element.nil?
    nil
  else
    brand_element.attr('href')
  end
end

def parse_models(brand)
  brand_path = get_brand_path brand

  if brand_path.nil?
    return false
  end

  url = "https://monro24.ru#{brand_path}&perpage=10000"
  document = Nokogiri::HTML.parse(open(url))

  CSV.open("#{brand} #{Time.now.strftime("%d.%m")}.csv", "wb") do |csv|
    document.css('.model-info').each do |model|
      title = model.css('.model-title span').text[2..-1]
      cost = model.css('.model-cost > span.number').text
      sizes = model.css('.model-sizes').text.sub('размеры: ', '')
      csv << [title, sizes]
    end
  end
  return true
end

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    brand = message.text
    if parse_models(brand) == true
      filename = "#{brand} #{Time.now.strftime("%d.%m")}.csv"
      bot.api.send_document(chat_id: message.chat.id, document: Faraday::UploadIO.new(filename, 'txt'))
      File.delete(filename) if File.exist?(filename)
    else
      bot.api.send_message(chat_id: message.chat.id, text: "Not found")
    end
  end
end
