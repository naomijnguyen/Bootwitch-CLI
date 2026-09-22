class Bootwitch < Formula
  desc "Portable project scaffolder for macOS and Linux"
  homepage "https://github.com/naomijnguyen/Bootwitch-CLI"
  url "https://github.com/naomijnguyen/Bootwitch-CLI/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "4b14c7cad72afa3bb39f483c1c0e37b3cfd6a87d1234ef943990507a0893cf26"
  version "0.3.0"
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
    assert_match "Templates:", shell_output("#{bin}/bootwitch templates")
    system bin/"bootwitch", "init", "brew-smoke", "--template", "base",
           "--root", testpath.to_s, "--no-git"
    assert_path_exists testpath/"brew-smoke/.bootwitch/project.conf"
  end
end
