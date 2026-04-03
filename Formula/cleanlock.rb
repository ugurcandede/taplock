class Cleanlock < Formula
  desc "Temporarily disable keyboard and trackpad while cleaning your Mac"
  homepage "https://github.com/ugurcandede/cleanlock"
  url "https://github.com/ugurcandede/cleanlock/releases/download/vVERSION/cleanlock-macos.zip"
  sha256 "SHA256_PLACEHOLDER"
  license "MIT"

  def install
    bin.install "cleanlock-universal" => "cleanlock"
  end

  def caveats
    <<~EOS
      CleanLock needs Accessibility permission to block input.
      It will guide you through this on first run.
    EOS
  end

  test do
    system "#{bin}/cleanlock", "--version"
  end
end
