class Bootwitch < Formula
  desc "Portable project scaffolder for macOS and Linux"
  homepage "https://github.com/naomijnguyen/Bootwitch-CLI"
  url "https://github.com/naomijnguyen/Bootwitch-CLI/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "7c148de0cf80991d688f8749181c1fa534e82ae3d993c6d1c9ad5dfbbc47de3e"
  version "0.2.1"
  license "MIT"

  depends_on "python@3.14"
  uses_from_macos "git"

  def install
    libexec.install Dir["*"]

    (bin/"bootwitch").write <<~EOS
      #!/usr/bin/env bash
      exec #{libexec}/bin/bootwitch "$@"
    EOS
    chmod 0555, bin/"bootwitch"
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/bootwitch help")
  end
end
