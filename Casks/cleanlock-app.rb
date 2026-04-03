cask "cleanlock-app" do
  version "VERSION"
  sha256 "SHA256_PLACEHOLDER"

  url "https://github.com/ugurcandede/cleanlock-app/releases/download/v#{version}/CleanLock-macos.zip"
  name "CleanLock"
  desc "Menu bar app to temporarily disable keyboard and trackpad while cleaning your Mac"
  homepage "https://github.com/ugurcandede/cleanlock-app"

  app "CleanLock.app"

  postflight do
    system "xattr", "-cr", "#{appdir}/CleanLock.app"
  end

  uninstall quit: "com.ugurcandede.cleanlock"

  caveats <<~EOS
    CleanLock needs Accessibility permission to block input.
    It will prompt you on first launch.
    Grant permission in System Settings > Privacy & Security > Accessibility.
  EOS
end
