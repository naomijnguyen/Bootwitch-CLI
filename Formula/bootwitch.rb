class Bootwitch < Formula
  desc 'Portable project scaffolder for macOS and Linux'
  homepage 'https://github.com/naomijnguyen/bootwitch'
  url 'https://github.com/naomijnguyen/bootwitch/archive/refs/tags/v0.2.0.tar.gz'
  sha256 'd4ff4b00fe19bb12b1ccdd304dd6f9bb6a4230295c61d059cc07efaae2b8cc25'
  version '0.2.0'
  license 'MIT'

  def install
    libexec.install Dir['*']

    (bin/'bootwitch').write <<~EOS
      #!/usr/bin/env bash
      exec #{libexec}/bin/bootwitch "$@"
    EOS
    chmod 0555, bin/'bootwitch'
  end

  test do
    assert_match 'Usage:', shell_output("#{bin}/bootwitch help")
  end
end
