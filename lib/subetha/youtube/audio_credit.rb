module Subetha
  module Youtube
    # Turns a downloaded post's sound label (see Tiktok::Audio.label) into a
    # credit line for the description:
    #
    #   original sound - Steven K.          -> Original sound by Steven K. (TikTok)
    #   Song Name - Some Band               -> "Song Name" by Some Band (TikTok)
    #   original sound - Me (own audio)     -> nil, nothing to credit
    module AudioCredit
      def self.from_label(label, source: "TikTok")
        label = label.to_s.strip
        return nil if label.empty? || label.end_with?("(own audio)")

        if (m = label.match(/\Aoriginal sound\s*-\s*(.+)\z/i))
          return "Original sound by #{m[1].strip} (#{source})"
        end
        return nil if label.casecmp?("original sound")

        title, sep, artist = label.rpartition(" - ")
        sep.empty? ? %("#{label}" (#{source})) : %("#{title}" by #{artist} (#{source}))
      end

      # Appends the credit as the last line, once.
      def self.append(description, credit)
        return description if credit.nil? || description.include?(credit)

        "#{description.rstrip}\n\n#{credit}"
      end
    end
  end
end
