module Transferatu
  class Transfer < Sequel::Model
    class AlreadyFailed < StandardError
      def initialize(xfer); super("Transfer #{xfer.uuid} already failed"); end
    end
    class AlreadySucceeded < StandardError
      def initialize(xfer); super("Transfer #{xfer.uuid} already succeeded"); end
    end

    include Transferatu::Loggable

    plugin :timestamps
    plugin :paranoid

    many_to_one :group
    many_to_one :schedule

    attr_secure :from_url, :secret => Config.at_rest_fernet_secret
    attr_secure :to_url, :secret => Config.at_rest_fernet_secret

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

    def_dataset_method(:in_progress) do
      self.where(Sequel.~(started_at: nil), canceled_at: nil, finished_at: nil)
    end

    def_dataset_method(:pending) do
      self.where(started_at: nil, canceled_at: nil, finished_at: nil)
    end

    # Flag transfer as canceled. Do nothing if the transfer has already finished.
    def cancel
      unless finished? || canceled?
        self.update(canceled_at: Time.now, finished_at: Time.now, succeeded: false)
      end
    end

    # Has this transfer been flag to be canceled?
    def canceled?
      !self.canceled_at.nil?
    end

    # Transfer has started processing
    def started?
      !self.started_at.nil?
    end

    # Has not yet completed. Note that a canceled transfer may briefly
    # be in progress before the cancelation is processed.
    def in_progress?
      started? && !finished?
    end

    # Transfer has finished, whether successfully or not
    def finished?
      !self.finished_at.nil?
    end

    # Transfer has finished successfully
    def succeeded?
      finished? && succeeded
    end

    # Flag transfer as successfully completed
    def complete
      if succeeded?
        # do nothing
      elsif failed?
        raise AlreadyFailed, self
      else
        self.update(finished_at: Time.now, succeeded: true)
      end
    end

    # Transfer has finished unsuccessfully
    def failed?
      finished? && !succeeded
    end

    # Flag transfer as unsusccessfully completed
    def fail
      if failed?
        # do nothing
      elsif succeeded?
        raise AlreadySucceeded, self
      else
        self.update(finished_at: Time.now, succeeded: false)
      end
    end

    def retry
      self.update(finished_at: nil, succeeded: nil, started_at: nil,
                  deleted_at: nil, purged_at: nil, canceled_at: nil,
                  processed_bytes: 0, source_bytes: 0)
    end

    # Mark transfer as deleted, and cancel it if it is in progress
    def after_destroy
      cancel if in_progress?
      super
    end

    # Update the transfer to indicate the number of +bytes+ that have
    # been processed so far. Note that this may be called (shortly)
    # after a transfer finishes, since progress reporting is
    # asynchronous.
    def mark_progress(bytes)
      # N.B.: we do *not* use update here to ensure that we trigger an
      # +updated_at+ change even when we've made no other
      # progress. This helps clarify the distinction between "still
      # running but has not yet processed any more data" and "it's an
      # ex-transfer, pining for the fjords".
      self.processed_bytes = bytes
      self.modified! :processed_bytes
      self.save_changes
      self.log("progress: #{bytes}", transient: true)
    end

    # Log a message relating to this transfer
    def log(message, level: :info, transient: false)
      unless level == :internal
        group.log message
      end
      unless transient
        super(message, level: level)
      end
    end
  end
end
