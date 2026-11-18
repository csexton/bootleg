RSpec.describe Bootleg::Youtube::AudioCredit do
  describe ".from_label" do
    {
      "original sound - Steven K."            => "Original sound by Steven K. (TikTok)",
      "Original Sound -  Owen "               => "Original sound by Owen (TikTok)",
      "Song Name - Some Band"                 => '"Song Name" by Some Band (TikTok)',
      "A - B - Some Band"                     => '"A - B" by Some Band (TikTok)',
      "Just A Song"                           => '"Just A Song" (TikTok)',
      "original sound - C. Sexton (own audio)" => nil,
      "original sound"                        => nil,
      ""                                      => nil,
      nil                                     => nil
    }.each do |label, credit|
      it "turns #{label.inspect} into #{credit.inspect}" do
        expect(described_class.from_label(label)).to eq(credit)
      end
    end
  end

  describe ".append" do
    it "adds the credit as a final paragraph" do
      expect(described_class.append("Caption  \n", "Credit")).to eq("Caption\n\nCredit")
    end

    it "adds it only once" do
      expect(described_class.append("Caption\n\nCredit", "Credit")).to eq("Caption\n\nCredit")
    end

    it "leaves the description alone when there is nothing to credit" do
      expect(described_class.append("Caption", nil)).to eq("Caption")
    end
  end
end
