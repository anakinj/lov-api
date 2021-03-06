require 'mini_magick'

module LovApi
  class ImageEndpoint < Sinatra::Base
    IMAGE_ROOT = File.join(API_ROOT, 'images').freeze

    def logger
      @logger ||= Logger.new(File.join(API_ROOT, '/log/image_endpoint.log'))
    end

    get '/image/latest' do
      user = params[:user] || env['REMOTE_USER']
      send_file File.join(user_image_folder(user), 'latest.jpg')
    end

    post '/image' do
      halt 400 unless params.key?(:file) || params[:file].is_a?(Hash) || params[:file].key?(:filename)
      now = Time.now
      user_image_folder_path = user_image_folder(env['REMOTE_USER'])
      year_path = File.join(now.year.to_s, now.month.to_s, now.day.to_s)
      image_folder = File.join(user_image_folder_path, year_path)
      image_name = "#{now.to_i}_#{params[:file][:filename]}"

      FileUtils.mkdir_p(image_folder)
      image_file = File.join(image_folder, image_name)

      begin
        image = MiniMagick::Image.open(params[:file][:tempfile].path)
        image.combine_options do |c|
          c.gravity 'Southwest'
          c.draw "text 10,10 \"#{now}\""
          c.fill('#FFFFFF')
        end
        image.write(image_file)
      rescue StandardError => e
        logger.warn("ImageMagick processing failed, using fallback store mechanism. #{e}")
        File.open(image_file, 'wb') do |f|
          f.write(params[:file][:tempfile].read)
        end
      end

      FileUtils.ln_s(File.join(year_path, image_name),
                     File.join(user_image_folder_path, 'latest.jpg'),
                     force: true)

      logger.info("Stored #{image_file}. Took #{(Time.now - now)} seconds")
      status 201
    end

    private

    def user_image_folder(user)
      File.join(IMAGE_ROOT, user)
    end
  end
end
