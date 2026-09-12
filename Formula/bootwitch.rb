class Bootwitch < Formula
  desc 'Portable project scaffolder for macOS and Linux'
  homepage 'https://github.com/naomijnguyen/bootwitch'
  url 'https://github.com/naomijnguyen/bootwitch/archive/refs/tags/v0.2.1.tar.gz'
  sha256 'e2555cd93a0312405cfcd0b8631ec060fff0abe8f4ca24fd94c23fa1c12c474e'
  version '0.2.1'
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
