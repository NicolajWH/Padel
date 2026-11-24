# frozen_string_literal: true
# Revoke only newly issued development identities installed on this ephemeral runner.
require 'json'
require 'openssl'
require 'base64'
require 'net/http'
require 'uri'
require 'open3'
require 'set'
require 'jwt'

module TemporarySigning
  HOST = 'api.appstoreconnect.apple.com'
  TYPES = %w[DEVELOPMENT IOS_DEVELOPMENT].freeze

  def self.request(method, url)
    uri = URI(url)
    raise 'Unexpected certificate API URL' unless uri.scheme == 'https' && uri.host == HOST && uri.port == 443 && uri.userinfo.nil? && uri.path.start_with?('/v1/certificates')
    now = Time.now.to_i
    key = OpenSSL::PKey.read(File.read(ENV.fetch('APP_STORE_CONNECT_API_KEY_PATH')))
    token = JWT.encode({iss: ENV.fetch('APP_STORE_CONNECT_ISSUER_ID').strip, iat: now, exp: now + 600, aud: 'appstoreconnect-v1'}, key, 'ES256', {kid: ENV.fetch('APP_STORE_CONNECT_KEY_ID').strip, typ: 'JWT'})
    req = method == :delete ? Net::HTTP::Delete.new(uri) : Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{token}"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) { |http| http.request(req) }
    return {} if method == :delete && %w[204 404].include?(response.code)
    raise "Certificate API #{method} failed (HTTP #{response.code})" unless response.code == '200' && method == :get
    JSON.parse(response.body)
  end

  def self.remote
    url = "https://#{HOST}/v1/certificates?limit=200"
    rows = []
    seen = Set.new
    while url
      raise 'Certificate API pagination loop' unless seen.add?(url)
      page = request(:get, url)
      rows.concat(page.fetch('data'))
      url = page.fetch('links', {})['next']
    end
    rows
  end

  def self.identities
    output, _, status = Open3.capture3('security', 'find-identity', '-p', 'codesigning')
    raise 'Cannot inspect local signing identities' unless status.success?
    output.scan(/^\s*\d+\)\s+([0-9A-Fa-f]{40})\s+"/).flatten.map(&:upcase).to_set
  end

  def self.candidates(before_ids:, before_local:, after_remote:, after_local:, team:, started:)
    after_remote.select do |row|
      next false if before_ids.include?(row.fetch('id'))
      attrs = row.fetch('attributes')
      next false unless TYPES.include?(attrs['certificateType']) && attrs['certificateContent']
      begin
        cert = OpenSSL::X509::Certificate.new(Base64.strict_decode64(attrs['certificateContent']))
        fingerprint = OpenSSL::Digest::SHA1.hexdigest(cert.to_der).upcase
        subject = cert.subject.to_a
        next false unless subject.any? { |name, value, _| name == 'OU' && value == team }
        next false unless subject.any? { |name, value, _| name == 'CN' && (value.start_with?('Apple Development:') || value.start_with?('iPhone Developer:')) }
        next false if cert.not_before < started - 300 || cert.not_before > Time.now + 300
        after_local.include?(fingerprint) && !before_local.include?(fingerprint)
      rescue OpenSSL::X509::CertificateError, ArgumentError
        false
      end
    end
  end

  def self.snapshot(path)
    state = { 'run' => ENV.fetch('GITHUB_RUN_ID'), 'attempt' => ENV.fetch('GITHUB_RUN_ATTEMPT'),
      'team' => ENV.fetch('APPLE_TEAM_ID').strip, 'started' => Time.now.to_i,
      'ids' => remote.map { |row| row.fetch('id') }, 'local' => identities.to_a }
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) { |file| file.write(JSON.generate(state)) }
    puts "Signing snapshot captured (#{state['ids'].length} existing certificates)."
  end

  def self.cleanup(path)
    unless File.file?(path)
      puts 'No signing snapshot; no certificates will be revoked.'
      return
    end
    state = JSON.parse(File.read(path))
    team = ENV.fetch('APPLE_TEAM_ID').strip
    raise 'Signing snapshot does not belong to this run' unless state.fetch('run') == ENV.fetch('GITHUB_RUN_ID') && state.fetch('attempt') == ENV.fetch('GITHUB_RUN_ATTEMPT') && state.fetch('team') == team
    rows = candidates(before_ids: state.fetch('ids').to_set, before_local: state.fetch('local').to_set,
      after_remote: remote, after_local: identities, team: team, started: Time.at(state.fetch('started')))
    puts "Verified #{rows.length} newly created local development certificate(s)."
    rows.each do |row|
      id = row.fetch('id')
      raise 'Unexpected certificate ID' unless id.match?(/\A[A-Za-z0-9-]+\z/)
      request(:delete, "https://#{HOST}/v1/certificates/#{id}")
      puts 'Revoked one verified temporary development certificate.'
    end
    puts 'Certificate cleanup finished; distribution and pre-existing certificates preserved.'
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    raise 'Hosted GitHub Actions runner required' unless ENV['GITHUB_ACTIONS'] == 'true' && ENV['RUNNER_ENVIRONMENT'] == 'github-hosted'
    path = File.join(ENV.fetch('RUNNER_TEMP'), 'padel-signing-snapshot.json')
    case ARGV.fetch(0)
    when 'snapshot' then TemporarySigning.snapshot(path)
    when 'cleanup' then TemporarySigning.cleanup(path)
    else raise 'Unknown signing cleanup operation'
    end
  rescue StandardError => error
    # Never print exception bodies, API responses, or key material.
    warn "Signing certificate operation failed (#{error.class}). No unverified certificate will be revoked."
    exit 1
  end
end
