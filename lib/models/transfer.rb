module Transferatu
  class Transfer < Sequel::Model

    include Transferatu::Loggable

    plugin :timestamps
    plugin :paranoid

    many_to_one :group

    def self.begin_next_pending
      self.db.transaction(isolation: :serializable) do
        Transfer.with_sql(<<-EOF).first
WITH oldest_pending AS (
  SELECT uuid FROM transfers WHERE started_at IS NULL ORDER BY created_at LIMIT 1
)
UPDATE
  transfers SET started_at = now()
FROM
  oldest_pending
WHERE
  oldest_pending.uuid = transfers.uuid
RETURNING *
EOF
      end
    end
    
    # Flag transfer as canceled. A canceled transfer will be flagged
    # as failed as soon as possible.
    def cancel
      self.update(canceled_at: Time.now)
      self.reload
    end

    # Has this transfer been flag to be canceled? Note that the
    # cancelation is in progress until finished_at is non-nil
    def canceled?
      # Always load the latest value, since cancelations will come in
      # through the database.
      !self.this.get(:canceled_at).nil?
    end

    # Transfer has finished, whether successfully or not
    def finished?
      !self.finished_at.nil?
    end

    # Transfer has finished successfully
    def succeeded?
      !self.finished_at.nil? && self.succeeded
    end

    # Flag transfer as successfully completed
    def complete
      self.update(finished_at: Time.now, succeeded: true)
    end

    # Transfer has finished unsuccessfully
    def failed?
      !self.finished_at.nil? && !self.succeeded
    end

    # Flag transfer as unsusccessfully completed
    def fail
      self.update(finished_at: Time.now, succeeded: false)
    end

    # Has not yet completed. Note that a canceled transfer may briefly
    # be in progress before the cancelation is processed.
    def in_progress?
      self.finished_at.nil?
    end

    # Update the transfer to indicate the number of +bytes+ that have
    # been processed so far. Note that this may be called (shortly)
    # after a transfer finishes, since progress reporting is
    # asynchronous.
    def mark_progress(bytes)
      self.update(processed_bytes: bytes)
      self.log("progress: #{bytes}", transient: true)
    end

    def log(message, severity: :info, transient: false)
      unless severity == :internal || logplex_token.nil?
        # send to logplex with user logplex token
      end
      unless transient
        super(message, severity: severity)
      end
    end    
  end
end
