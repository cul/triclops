module Triclops::Utils::TokenUtils
  def self.token_is_valid?(token, base_type, resource_identifier, client_ip)
    # To support image proxy endpoints, always consider the triclops
    # main remote request api key to be a valid token.
    return true if token == TRICLOPS['remote_request_api_key']
    puts "Token is: #{token}"
    # The token should have been created with:
    # token = JWT.encode payload, TRICLOPS['jwt_hmac_secret'], 'HS256'
    decoded_token = JWT.decode token, TRICLOPS['jwt_hmac_secret'], true, { algorithm: 'HS256' }
    payload = decoded_token[0]

    return false if payload['base_type'] != base_type
    return false if payload['identifier'] != resource_identifier
    return false if payload['client_ip'] != client_ip
    true
  rescue JWT::ExpiredSignature
    # This rescue block will be triggered if the token was generated with an expiration
    # time (Unix epoch seconds) and that expiration time has passed.
    # Example of how this is encoded:
    # exp = Time.now.to_i + 4 * 3600
    # token = JWT.encode { data: 'data', exp: exp }, hmac_secret, 'HS256'
    false
  end
end
