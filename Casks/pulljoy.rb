cask "pulljoy" do
  version "1.1.0"
  sha256 "df4b01ab3479a55ec1e77385f6637c1448b128ff13f79a9976f9fbe458eb30ed"

  url "https://api.github.com/repos/noma4i/pulljoy/releases/assets/617779012",
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
