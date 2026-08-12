require_relative "integration_test"

class RolloutTest < IntegrationTest
  setup do
    @app = "app_with_rollout"
  end

  test "a rollout takes only the cohort that carries the cookie" do
    kamal :deploy
    live_version = latest_app_version
    assert_app_is_up version: live_version

    rollout_version = update_app_rev
    assert_not_equal live_version, rollout_version

    kamal :rollout, :boot

    assert_equal live_version, app_version_for, "booting a rollout must not move any traffic"
    assert_equal live_version, app_version_for(cookie: "kamal-rollout=in-the-cohort")

    kamal :rollout, :set, "--list", "in-the-cohort"

    assert_equal rollout_version, app_version_for(cookie: "kamal-rollout=in-the-cohort")
    assert_equal live_version, app_version_for(cookie: "kamal-rollout=not-in-the-cohort")
    assert_equal live_version, app_version_for, "a request without the cookie never rolls over"

    kamal :rollout, :remove, "-y"

    assert_equal live_version, app_version_for(cookie: "kamal-rollout=in-the-cohort")
    assert_app_is_up version: live_version
  end

  test "a percentage split is sticky for a given cookie value" do
    kamal :deploy
    live_version = latest_app_version

    rollout_version = update_app_rev
    kamal :rollout, :boot
    kamal :rollout, :set, "--percent", "50"

    cookie = "kamal-rollout=#{cohort_value_within(50)}"
    3.times { assert_equal rollout_version, app_version_for(cookie: cookie) }
    assert_equal live_version, app_version_for
  end

  test "a deploy leaves a live rollout alone" do
    kamal :deploy

    rollout_version = update_app_rev
    kamal :rollout, :boot
    kamal :rollout, :set, "--percent", "50"

    output = kamal :deploy, capture: true
    assert_match "Rollout still live", output

    assert_equal rollout_version, app_version_for(cookie: "kamal-rollout=#{cohort_value_within(50)}")
  end

  test "set refuses a percentage above max_percent" do
    kamal :deploy
    update_app_rev
    kamal :rollout, :boot

    output = kamal :rollout, :set, "--percent", "80", capture: true, raise_on_error: false
    assert_match "exceeds rollout/max_percent of 50", output
  end

  test "disabling keeps the split, and details reports it" do
    skip_unless_proxy_supports_rollout_enable

    kamal :deploy
    live_version = latest_app_version

    rollout_version = update_app_rev
    kamal :rollout, :boot
    kamal :rollout, :set, "--list", "in-the-cohort"

    assert_match "Split     list of 1, enabled ->", kamal(:rollout, :details, capture: true)
    assert_equal rollout_version, app_version_for(cookie: "kamal-rollout=in-the-cohort")

    kamal :rollout, :disable
    assert_equal live_version, app_version_for(cookie: "kamal-rollout=in-the-cohort")
    assert_match "disabled ->", kamal(:rollout, :details, capture: true)

    kamal :rollout, :enable
    assert_equal rollout_version, app_version_for(cookie: "kamal-rollout=in-the-cohort"),
      "enabling must restore the split without being given it again"
  end

  private
    # rollout enable/disable and `list --format json` landed after v0.9.2, which is what
    # the suite pulls. Set KAMAL_PROXY_IMAGE_VERSION to a build that has them.
    def skip_unless_proxy_supports_rollout_enable
      skip "needs a kamal-proxy with rollout enable/disable" unless ENV["KAMAL_PROXY_IMAGE_VERSION"]
    end

    # The proxy buckets on an FNV-1a hash of the cookie, so find a value that lands
    # inside the split rather than assuming one does.
    def cohort_value_within(percent)
      split_point = 0xFFFFFFFF * (percent / 100.0)

      100.times do |i|
        return "value-#{i}" if fnv1a("value-#{i}") <= split_point
      end

      flunk "no cookie value fell within #{percent}%"
    end

    def fnv1a(value)
      value.each_byte.reduce(2166136261) { |hash, byte| ((hash ^ byte) * 16777619) & 0xFFFFFFFF }
    end
end
