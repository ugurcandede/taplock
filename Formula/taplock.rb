class Taplock < Formula
  desc "Temporarily disable keyboard and trackpad input on your Mac"
  homepage "https://github.com/ugurcandede/taplock"
  url "https://github.com/ugurcandede/taplock/releases/download/vVERSION/taplock-macos.zip"
  sha256 "SHA256_PLACEHOLDER"
  license :cannot_represent

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
