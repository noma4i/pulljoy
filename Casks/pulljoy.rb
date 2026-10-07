cask "pulljoy" do
  version "1.1.1"
  sha256 "651c0b9f4f950f5cff5fdb0ebdea1e098e2cbdb6a6f21393027f60a6ca5ffdfe"

  url "https://api.github.com/repos/noma4i/pulljoy/releases/assets/617810345",
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
