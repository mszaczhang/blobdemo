# Require the azure storage gem
require 'azure/storage'

# There is default version parameter 2015-04-05 in azure-storage gem
# Overwrite the version paramater to be used in http header
Azure::Storage::Default::STG_VERSION = '2016-05-31' 

### Prepare the file to be upload
file_to_upload = 'FILE_TO_UPLOAD'  # File name of Local file to upload

### Prepare Azure Storage parematers
storage_account_name = 'YOUR_STORAGE_ACCOUNT_NAME' # Please fill your Azure Storage Account Name
storage_access_key = 'YOUR_STORAGE_ACCESS_KEY'     # Please fill your Azure Storage Access Key
container_name = 'YOUR_CONTAINER_NAME'  # An existing azure container name to save file  
blob_name = 'REMOTE_FILE_NAME'          # Remote file name on Azure storage which can be same as local file name or not
block_size = 8 * 1024 * 1024

### Setup a specific instance
client = Azure::Storage::Client.create(:storage_account_name => storage_account_name, :storage_access_key => storage_access_key)
blob_service = Azure::Storage::Blob::BlobService.new(client: client)

###  The following code shows how to create a single block blob file .
# client.blob_client.create_block_blob(container_name, blob_name, ::File.open(file_to_upload, 'rb'){|file| file.read})

### Generate a random string
module RandomString
  def self.random_name
    (0...8).map { ('a'..'z').to_a[rand(26)] }.join
  end
end

### Overwrite the defaut Azure::Core::Http:HttpRequest call function 
### To output HTTP request method, URI, headers, and small body.
module Azure
  module Core
    module Http
      class HttpRequest
        def call
          conn = http_setup
          print "HTTP Method: ",  method.to_sym, "\n"
          print "HTTP request URI: ", uri, "\n"
          puts headers
          if headers['Content-Length'].to_i < 10240
            puts body
          end
          res = set_up_response(method.to_sym, uri, conn, headers ,body)

          response = HttpResponse.new(res)
          response.uri = uri
          raise response.error if !response.success? && !@has_retry_filter
          response
        end
      end
    end
  end
end
# Azure::Core::Http::HttpRequest.include LogHttpExt


### The following code block comes from Azure Sample 
### https://github.com/Azure-Samples/storage-blob-ruby-getting-started/blob/master/blobs_advanced.rb
### 'block_blob_operations' function

blocks = []
# Read the file
puts 'Upload file to block blob.  Local file: '+ file_to_upload
File.open file_to_upload, 'rb' do |file|
  while (file_bytes = file.read(block_size))
    block_id = Base64.strict_encode64(RandomString.random_name)
    puts block_id
    blob_service.put_blob_block(container_name,
                                blob_name,
                                block_id,
                                file_bytes)
    blocks << [block_id]
  end
end

puts 'Commit blocks'
blob_service.commit_blob_blocks(container_name, blob_name, blocks)

puts 'List blocks in block blob'
list_blocks = blob_service.list_blob_blocks(container_name, blob_name)

list_blocks[:committed].each { |block| puts "Block #{block.name}" }

