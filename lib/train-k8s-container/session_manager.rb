# frozen_string_literal: true

require 'singleton'
require_relative 'pty_session'

module TrainPlugins
  module K8sContainer
    # Thread-safe manager for PTY session pool
    # Maintains one session per unique namespace/pod/container combination
    class SessionManager
      include Singleton

      def initialize
        @sessions = {}
        @mutex = Mutex.new
        @cleanup_registered = false
        register_cleanup
      end

      # Get or create a session for the given key
      # @param session_key [String] Unique key "namespace/pod/container"
      # @param kubectl_cmd [String] Base kubectl exec command
      # @param shell [String] Shell to use (/bin/bash, /bin/sh, etc.)
      # @param timeout [Integer] Session timeout in seconds
      # @param logger [Logger] Logger instance
      # @return [PtySession] Active session
      def get_session(session_key, kubectl_cmd:, shell: '/bin/bash', timeout: 300, logger: nil)
        @mutex.synchronize do
          unless @sessions[session_key]&.healthy?
            # Cleanup old session if exists (must be done inside mutex, not via cleanup_session)
            if @sessions[session_key]
              old_session = @sessions.delete(session_key)
              old_session&.cleanup
            end

            logger&.debug("Creating new PTY session for #{session_key}")
            @sessions[session_key] = PtySession.new(
              session_key: session_key,
              kubectl_cmd: kubectl_cmd,
              shell: shell,
              timeout: timeout,
              logger: logger
            )
            @sessions[session_key].connect
          end

          @sessions[session_key]
        end
      rescue PtySession::PtyError
        # Cleanup without recursive mutex (already inside synchronize block)
        @sessions.delete(session_key)
        raise
      end

      # Cleanup a specific session
      # @param session_key [String] Session to cleanup
      def cleanup_session(session_key)
        @mutex.synchronize do
          session = @sessions.delete(session_key)
          session&.cleanup
        end
      end

      # Cleanup all sessions
      def cleanup_all
        @mutex.synchronize do
          @sessions.each_value(&:cleanup)
          @sessions.clear
        end
      end

      # Get session count (for monitoring/testing)
      def session_count
        @sessions.size
      end

      # Get all session keys (for monitoring/testing)
      def session_keys
        @sessions.keys
      end

      private

      def register_cleanup
        return if @cleanup_registered

        at_exit do
          cleanup_all
        end

        @cleanup_registered = true
      end
    end
  end
end
