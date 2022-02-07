class Application::DocumentRecognitionIndexWorker
  COLLECTION_NAMES = %w[front_doc selfie selfie_doc].freeze

  include Sidekiq::Worker

  sidekiq_options queue: :recognitions, retry: 10

  attr_accessor :application, :application_id, :image_front,
                :image_selfie, :application_collection, :bucket

  def perform(application_id)
    @application_id = application_id
    @application = Application.find(application_id)
    @image_front = fetch_image('cmnd_front')
    @image_selfie = fetch_image('cmnd_selfie')
    @application_collection = "#{application.id}_#{Rails.env}"
    @bucket = AMAZON_SETTINGS['aws_bucket']

    return if documents_invalid?

    initialize_collections
    add_to_collections

    Application::DocumentRecognitionCompare.new.run(application_id)
    Application::DocumentHistoricalSimilarity.new.run(application_id)
  rescue => e
    write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker perform #{e}"
  end

  private

  def write_message_to_log(message, filename = 'aws_rekognition')
    File.open("#{Rails.root}/log/#{filename}.log", 'a') { |f| f.puts message }
  end

  def documents_invalid?
    return true if image_front.nil? || image_selfie.nil?

    cmnd_front = client.detect_faces(image: { s3_object: { bucket: bucket, name: image_front.key } })
    Document::AwsLogService.call(application, 'detect_faces')

    cmnd_selfie = client.detect_faces(image: { s3_object: { bucket: bucket, name: image_selfie.key } })
    Document::AwsLogService.call(application, 'detect_faces')

    cmnd_front_count = cmnd_front.face_details.count
    cmnd_selfie_count = cmnd_selfie.face_details.count

    write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker documents_invalid? (face_details) - cmnd_front: #{cmnd_front_count} != 1, cmnd_selfie: #{cmnd_selfie_count} != 2"

    if cmnd_front_count != 1
      write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker documents_invalid? Detect 2 faces on front docs: confidences: #{cmnd_front.face_details.map{|x| p x.confidence}}  "

      check = cmnd_front.face_details.select { |element| element.confidence > 90 }

      return true if check.count !=1
    end

    return true if cmnd_selfie_count != 2
  rescue => e
    write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker documents_invalid? #{e}"

    true
  end

  def add_to_collections
    COLLECTION_NAMES.each do |collection_name|
      @object_info = {
        file_key: collection_name.match?('selfie') ? image_selfie.key : image_front.key,
        collection_common: "#{collection_name}_#{Rails.env}",
        collection_application: application_collection,
        collection_name: collection_name,
        external_image_id: "#{collection_name}_#{application_id}"
      }

      # inside application collection
      index_faces_tmp
      # inside common collections
      face_id = index_faces_common

      application.application_faces.find_or_create_by(collection: @object_info[:collection_common], face_id: face_id) if face_id.present?
    end
  end

  def index_faces_tmp
    response = aws_index_faces(@object_info[:collection_application])

    first_face_id = response.face_records.first.face.face_id
    last_face_id = response.face_records.last.face.face_id

    delete_faces_regular_logic(@object_info[:collection_application], first_face_id, last_face_id)
  rescue StandardError => e
    write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker index_faces_tmp #{e}"
  end

  def index_faces_common
    response = aws_index_faces(@object_info[:collection_common])

    first_face_id = response.face_records.first.face.face_id
    last_face_id = response.face_records.last.face.face_id

    if response.face_records.size.eql?(1)
      return delete_faces_one_face_logic(@object_info[:collection_common], first_face_id)
    end

    delete_faces_regular_logic(@object_info[:collection_common], first_face_id, last_face_id)
  rescue StandardError => e
    write_message_to_log "Application: #{application_id} DocumentRecognitionIndexWorker index_faces_common #{e}"
  end

  def aws_index_faces(collection)
    client.index_faces(
      collection_id: collection,
      image: { s3_object:
                 { bucket: bucket,
                   name: @object_info[:file_key]
                 }
      },
      detection_attributes: ['ALL'],
      quality_filter: 'NONE',
      external_image_id: @object_info[:external_image_id]
    )
  end

  def aws_delete_face(collection, face)
    client.delete_faces(collection_id: collection, face_ids: face)
  end

  def delete_faces_regular_logic(collection, first_face_id, last_face_id)
    case @object_info[:collection_name]
    when 'front_doc'
      #DO_NOTHING
    when 'selfie'
      aws_delete_face(collection, [last_face_id])
    when 'selfie_doc'
      aws_delete_face(collection, [first_face_id])
      first_face_id = last_face_id
    else
      return
    end
    first_face_id
  end

  def delete_faces_one_face_logic(collection, first_face_id)
    case @object_info[:collection_name]
    when 'front_doc'
      #DO_NOTHING
    when 'selfie'
      #DO_NOTHING
    when 'selfie_doc'
      aws_delete_face(@object_info[:collection_common], [first_face_id])
      first_face_id = nil
    else
      first_face_id = nil
    end
    first_face_id
  end

  def initialize_collections
    aws_collections = client.list_collections
    Document::AwsLogService.call(application, 'list_collections')

    if aws_collections.collection_ids.exclude?(application_collection)
      client.create_collection(collection_id: application_collection)
      Document::AwsLogService.call(application, 'create_collection')
    end
  rescue StandardError => e
    write_message_to_log "Application: #{application.id} DocumentRecognitionIndexWorker initialize_collections #{e}"
  end

  def client
    @client ||= Aws::Rekognition::Client.new(
      profile: AMAZON_SETTINGS['profile'],
      region: AMAZON_SETTINGS['region'],
      credentials: Aws::Credentials.new(AMAZON_SETTINGS['key_id'], AMAZON_SETTINGS['secret_key'])
    )
  end

  def fetch_image(image_type)
    application.documents.find_by(ts_type_id: image_type)&.file_attach&.file&.to_file
  end
end
