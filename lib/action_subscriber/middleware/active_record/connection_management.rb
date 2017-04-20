require "concurrent"
require "thread"

module ActionSubscriber
  module Middleware
    module ActiveRecord
      class ConnectionManagement
        START_MUTEX = ::Mutex.new

        def self.start_timed_task!
          if timed_task_started.false?
            START_MUTEX.synchronize do
              return if timed_task_started.true?

              timed_task = ::Concurrent::TimerTask.new(
                :execution_interval => ::ActionSubscriber.config.connection_reaping_interval,
                :timeout_interval => ::ActionSubscriber.config.connection_reaping_timeout_interval) do

                ::ActiveRecord::Base.clear_active_connections!
                end

              timed_task.execute
              timed_task_started.make_true
            end
          end
        end

        def self.timed_task_started
          if @timed_task_started.nil?
            @timed_task_started = ::Concurrent::AtomicBoolean.new(false)
          end

          @timed_task_started
        end

        def initialize(app)
          @app = app
        end

        def call(env)
          def call(env)
            ::ActiveRecord::Base.connection_pool.with_connection do
              @app.call(env)
            end
          end

          self.class.start_timed_task!
          call(env)
        end

        timed_task_started
      end
    end
  end
end
