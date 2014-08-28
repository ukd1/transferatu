module Transferatu
  class ScheduleResolver

    # Attempt to resolve a schedule to a hash containing data for
    # creating a transfer, as if coming from a normal POST to the
    # +/groups/:name/transfers+ endpoint. If the schedule callback url
    # returns 404 or 410, return nil.
    def resolve(schedule)
      endpoint = resource(schedule.callback_url,
                          schedule.group.user.name,
                          schedule.group.user.callback_password)
      encrypted_result = begin
                           encrypted_result = endpoint.get
                         rescue RestClient::Gone, RestClient::ResourceNotFound => e
                           return nil
                         end
      result = decrypt(schedule.group.user.token, encrypted_result)
      JSON.parse(result)
    end

    private

    def decrypt(key, message)
      verifier = Fernet.verifier(key, message, ttl: 180)
      if verifier.valid?
        verifier.message
      else
        raise StandardError, "Could not decrypt callback response"
      end
    end

    def resource(callback_url, user, password)
      RestClient::Resource.new(callback_url,
                               user: user,
                               password: password,
                               headers: { content_type: 'application/octet-stream',
                                         accept: 'application/octet-stream' })
    end
  end
end
