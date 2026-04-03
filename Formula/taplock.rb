class Cleanlock < Formula
  desc "Temporarily disable keyboard and trackpad while cleaning your Mac"
  homepage "https://github.com/ugurcandede/taplock"
  url "https://github.com/ugurcandede/taplock/releases/download/vVERSION/taplock-macos.zip"
  sha256 "SHA256_PLACEHOLDER"
  license "MIT"

  def install
    bin.install "taplock-universal" => "taplock"
  end

  def caveats
    <<~EOS
      TapLock needs Accessibility permission to block input.
      It will guide you through this on first run.
    EOS
  end

  test do
    system "#{bin}/taplock", "--version"
  end
end
