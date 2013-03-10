class TweetPresenter
  def self.from_json(json)
    new(Twitter::Tweet.new(json))
  end

  def self.keywords_whitelist
    @whitelist ||= File.readlines('keywords_whitelist.txt').map do |pattern|
      pattern.strip!
      if pattern =~ /^"(.*)"$/
        # double quotes mean don't ignore case
        /\b#{$1}\b/
      else
        /\b#{pattern}\b/i
      end
    end
  end

  def self.user_awesomeness_threshold(user)
    # this is a completely non-scientific formula calculated by trial and error
    # in order to set the bar higher for users that get retweeted a lot (@dhh, @rails).
    # should be around 20 for most people and then raise to ~30 for @rails and 50+ for @dhh.
    # the idea is that if you have an army of followers, everything you write gets retweeted and favorited

    17.5 + (user.followers_count ** 1.25) * 25 / 1_000_000
  end

  def initialize(tweet)
    @tweet = tweet
  end

  [:id, :attrs, :created_at, :retweeted, :retweet_count, :text, :urls, :user].each do |method|
    define_method(method) do
      @tweet.send(method)
    end
  end

  def reply?
    text.start_with?('@')
  end

  def retweetable?
    !retweeted && interesting?
  end

  def interesting?
    matches_keywords? && above_threshold?
  end

  def above_threshold?
    activity_count >= user_awesomeness_threshold
  end

  def matches_keywords?
    self.class.keywords_whitelist.any? { |k| expanded_text =~ k }
  end

  def activity_count
    retweet_count + (favorites_count || 0)
  end

  def favorites_count
    count = @tweet.attrs[:favoriters_count]
    count && count.to_i
  end

  def user_awesomeness_threshold
    self.class.user_awesomeness_threshold(user)
  end

  def expanded_text
    unless @expanded_text
      @expanded_text = text.clone
      urls.each { |entity| @expanded_text[entity.url] = entity.display_url }
    end

    @expanded_text
  end
end
