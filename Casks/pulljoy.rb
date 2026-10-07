cask "pulljoy" do
  version "1.0.0"
  sha256 "b4c4ad434efa096ebf6284743c808d683a10598e6159d8abf5b0dbad88f7dd01"

  url "https://api.github.com/repos/noma4i/pulljoy/releases/assets/617676699",
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
