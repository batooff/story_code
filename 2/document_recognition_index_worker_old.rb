class Application::DocumentRecognitionIndexWorker
  include Sidekiq::Worker

  sidekiq_options queue: :recognitions, retry: 10

  def perform(application_id)
    client.list_collections

    @application = Application.find(application_id)
    @image_front = fetch_image('cmnd_front')
    @image_selfie = fetch_image('cmnd_selfie')
    @collection_name = "#{@application.id}_#{Rails.env}"

    Document::AwsLogService.call(@application, 'list_collections')

    return if documents_invalid?

    add_to_collections

    Application::DocumentRecognitionCompare.new.run(application_id)
    Application::DocumentHistoricalSimilarity.new.run(application_id)
  rescue => e
    write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker perform #{e}"
  end

  private

  def write_message_to_log(message, filename = 'aws_rekognition')
    File.open("#{Rails.root}/log/#{filename}.log", 'a') { |f| f.puts message } # if Time.now < Time.new(2019, 10, 16)
  end

  def documents_invalid?
    return true if @image_front == nil || @image_selfie == nil

    cmnd_front = client.detect_faces(
      image: { s3_object: { bucket: @image_front.bucket_name, name: @image_front.key } }
    )
    Document::AwsLogService.call(@application, 'detect_faces')

    cmnd_selfie = client.detect_faces(
      image: { s3_object: { bucket: @image_selfie.bucket_name, name: @image_selfie.key } }
    )
    Document::AwsLogService.call(@application, 'detect_faces')

    cmnd_front_count = cmnd_front.face_details.count
    cmnd_selfie_count = cmnd_selfie.face_details.count

    write_message_to_log "Application: #{@application.id} DocumentRecognitionIndexWorker documents_invalid? (face_details) - cmnd_front: #{cmnd_front_count} != 1, cmnd_selfie: #{cmnd_selfie_count} != 2"

    if cmnd_front_count != 1
      write_message_to_log "Application: #{@application.id} DocumentRecognitionIndexWorker documents_invalid? Detect 2 faces on front docs: confidences: #{cmnd_front.face_details.map{|x| p x.confidence}}  "

      check = cmnd_front.face_details.select { |element| element.confidence > 90 }

      return true if check.count !=1
    end

    return true if cmnd_selfie_count != 2
  rescue => e
    write_message_to_log "Application: #{@application.id} DocumentRecognitionIndexWorker documents_invalid? #{e}"

    true
  end

  def add_to_collections
    initialize_collections

    ids = []
    ids << { "front_doc_#{Rails.env}" => index_faces(@image_front, "front_doc_#{Rails.env}", "front_doc_#{@application.id}") }
    ids << { "selfie_#{Rails.env}" => index_faces(@image_selfie, "selfie_#{Rails.env}", "selfie_#{@application.id}") }
    ids << { "selfie_doc_#{Rails.env}" => index_faces(@image_selfie, "selfie_doc_#{Rails.env}", "selfie_doc_#{@application.id}") }

    index_faces(@image_front, @collection_name, "front_doc_#{@application.id}")
    index_faces(@image_selfie, @collection_name, "selfie_#{@application.id}")
    index_faces(@image_selfie, @collection_name, "selfie_doc_#{@application.id}")

    face_ids_to_application(ids)
  end

  def face_ids_to_application(ids)
    ids.map do |f|
      @application.application_faces.create(collection: f.keys.first, face_id: f.values.first)
    end
  end

  def index_faces(file, collection, type)
    response = client.index_faces(
      collection_id: collection,
      image: { s3_object: { bucket: AMAZON_SETTINGS['aws_bucket'], name: file.key } },
      detection_attributes: ['ALL'],
      quality_filter: 'NONE',
      external_image_id: type
    )

    Document::AwsLogService.call(@application, 'index_faces')

    deleted = type.exclude?('front_doc') ? delete_excess_faces(response, collection, type) : []
    (response.to_h[:face_records].map { |x| x[:face][:face_id] } - deleted).first
  rescue StandardError => e
    write_message_to_log "Application: #{@application.id} DocumentRecognitionIndexWorker index_faces #{e}"
  end

  def delete_excess_faces(response, collection, type)
    res = image_sizes(response)
    formatted_type = type.match(/(front_doc|selfie_doc|selfie)/)[0]
    res.delete(formatted_type)
    client.delete_faces(collection_id: collection, face_ids: res.values)
    Document::AwsLogService.call(@application, 'delete_faces')

    res.values
  rescue StandardError => e
    write_message_to_log "Application: #{@application.id} DocumentRecognitionIndexWorker delete_excess_faces #{e}"
  end

  def image_sizes(response)
    if calculate_size(response, 0) > calculate_size(response, 1)
      {
        'selfie' => response[:face_records][0][:face][:face_id],
        'selfie_doc' => response[:face_records][1][:face][:face_id]
      }
    else
      {
        'selfie' => response[:face_records][1][:face][:face_id],
        'selfie_doc' => response[:face_records][0][:face][:face_id]
      }
    end
  end

  def calculate_size(response, index)
    bounding_box = response[:face_records][index][:face][:bounding_box]
    bounding_box[:width] * bounding_box[:height]
  end

  def initialize_collections
    collections = client.list_collections
    Document::AwsLogService.call(@application, 'list_collections')

    [@application.id.to_s].each do |collection|
      collection = "#{collection}_#{Rails.env}"

      unless collections.collection_ids.include? collection
        client.create_collection(collection_id: collection)
        Document::AwsLogService.call(@application, 'create_collection')
      end
    end
  rescue StandardError => e
    write_message_to_log "Application: #{@application.id} DocumentRecognitionIndexWorker initialize_collections #{e}"
  end

  def client
    @client ||= Aws::Rekognition::Client.new(
      profile: AMAZON_SETTINGS['profile'],
      region: AMAZON_SETTINGS['region'],
      credentials: Aws::Credentials.new(AMAZON_SETTINGS['key_id'], AMAZON_SETTINGS['secret_key'])
    )
  end

  def fetch_image(image_type)
    if @application.document_links?
      @application.document_links.where(ts_type_id: image_type).last&.aws_file&.to_file
    else
      @application.documents.where(ts_type_id: image_type).last.file_attach&.file&.to_file
    end
  end
end
