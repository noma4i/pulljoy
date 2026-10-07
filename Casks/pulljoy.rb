cask "pulljoy" do
  version "1.1.2"
  sha256 "4d8fb9bf883bb8cf12ab602d85f512c37d76d62f5ed7b08f6620b0a72a26135a"

  url "https://api.github.com/repos/noma4i/pulljoy/releases/assets/617845357",
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
