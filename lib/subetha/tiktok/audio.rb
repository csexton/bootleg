module Subetha
  module Tiktok
    # The sound a post uses, normalized from TikTok's "music" object so the
    # sidecar can credit it. Returns nil when the post carries no usable sound.
    module Audio
      def self.from(raw, post_author_name)
        return nil unless raw.is_a?(Hash)

        title  = raw["title"].to_s.strip
        artist = (raw["authorName"] || raw["author"]).to_s.strip
        return nil if title.empty? && artist.empty?

        original = raw["original"] == true
        id       = raw["id"].to_s
        {
          title:    title,
          artist:   artist,
          original: original,
          # An "original sound" under the poster's own name is their own audio,
          # so there is nobody else to credit.
          own:      original && !artist.empty? &&
                    artist.casecmp?(post_author_name.to_s.strip),
          id:       id,
          url:      url_for(title, id)
        }
      end

      def self.url_for(title, id)
        return nil if id.empty?

        slug = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
        slug = "sound" if slug.empty?
        "https://www.tiktok.com/music/#{slug}-#{id}"
      end

      # "original sound - aubory bugg", with a note when it is the poster's own.
      def self.label(audio)
        title, artist = audio[:title], audio[:artist]
        # Some titles already carry the artist ("original sound - Hunny Hints").
        artist = "" if !artist.empty? && title.downcase.include?(artist.downcase)
        text = [title, artist].reject(&:empty?).join(" - ")
        audio[:own] ? "#{text} (own audio)" : text
      end
    end
  end
end
