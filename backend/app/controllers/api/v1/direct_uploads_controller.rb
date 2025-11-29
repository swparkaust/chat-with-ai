module Api
  module V1
    class DirectUploadsController < ApplicationController
      skip_before_action :set_current_user

      def create
        blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_args)
        render json: direct_upload_json(blob)
      rescue ActionController::BadRequest => e
        render json: { error: e.message }, status: :bad_request
      end

      private

      def blob_args
        args = params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, metadata: {}).to_h.symbolize_keys

        byte_size = args[:byte_size].to_i
        if byte_size <= 0 || byte_size > 10.megabytes
          raise ActionController::BadRequest, 'File size must be between 1 byte and 10 MB'
        end

        allowed_types = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
        unless allowed_types.include?(args[:content_type])
          raise ActionController::BadRequest, "Invalid content type. Allowed: #{allowed_types.join(', ')}"
        end

        args[:filename] = sanitize_filename(args[:filename])

        args
      end

      def sanitize_filename(filename)
        filename = File.basename(filename.to_s)
        filename[0..254]
      end

      def direct_upload_json(blob)
        blob.as_json(root: false, methods: :signed_id).merge(
          direct_upload: {
            url: blob.service_url_for_direct_upload,
            headers: blob.service_headers_for_direct_upload
          }
        )
      end
    end
  end
end
