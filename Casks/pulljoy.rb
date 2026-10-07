cask "pulljoy" do
  version "1.0.0"
  sha256 "5577cdb107a76c1ac2db62aea941360a9de43aa3f37a11e93e642dda964a7de9"

  url "https://api.github.com/repos/noma4i/pulljoy/releases/assets/617752995",
      header: [
        "Accept: application/octet-stream",
        "Authorization: Bearer #{ENV.fetch("HOMEBREW_GITHUB_API_TOKEN", "")}",
      ]
  name "PullJoy"
  desc "Menu-bar inbox of the pull requests waiting on you"
  homepage "https://github.com/noma4i/pulljoy"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "PullJoy.app"

  zap trash: [
    "~/Library/Preferences/com.noma4i.pulljoy.plist",
  ]
end
