RSpec.describe Subetha::Tiktok::Downloader do
  # Two posts from the same day whose captions open with the same words; this
  # pair really collided and cost one of them its file.
  let(:caption)    { "Rules are rules for a reason. This is so serious, not even joking." }
  let(:created_at) { Time.utc(2026, 6, 5, 12, 31, 46) }
  # Derived rather than hardcoded so the spec does not depend on the local zone.
  let(:date)       { Time.at(created_at.to_i).strftime("%Y-%m-%d") }
  let(:base_name)  { "deadrunwoodworks-#{date}-rules-are-rules-for-a-reason" }

  def post(id, description = caption)
    {
      author_id:   "deadrunwoodworks",
      author_name: "C. Sexton",
      create_time: created_at.to_i,
      video_id:    id,
      media_id:    id,
      description: description,
      video_url:   "https://cdn.example/#{id}.mp4",
      cookies:     nil
    }
  end

  describe "naming" do
    # Replaces the HTTP layer so naming can be exercised offline.
    let(:offline_downloader) do
      Class.new(described_class) do
        private

        def write_binary(url, path, *_args, **_kwargs)
          File.write(path, "fake-bytes:#{url}")
        end
      end
    end

    def downloader(**overrides)
      offline_downloader.new(config(**overrides))
    end

    it "keeps both posts when two captions slugify to the same name" do
      downloader.save_video(post("111"), "https://tiktok/111")
      downloader.save_video(post("222"), "https://tiktok/222")

      expect(files_in_output).to contain_exactly(
        "#{base_name}.mp4", "#{base_name}.txt",
        "#{base_name}-222.mp4", "#{base_name}-222.txt"
      )
    end

    it "leaves the post that owns the name untouched" do
      downloader.save_video(post("111"), "https://tiktok/111")
      downloader.save_video(post("222"), "https://tiktok/222")

      expect(read_output("#{base_name}.mp4")).to eq("fake-bytes:https://cdn.example/111.mp4")
    end

    it "says why it renamed" do
      downloader.save_video(post("111"), "https://tiktok/111")
      downloader.save_video(post("222"), "https://tiktok/222")

      expect(captured_stdout).to include("Name taken by 111; appending ID")
    end

    it "overwrites in place when the same post is downloaded again" do
      2.times { downloader.save_video(post("111"), "https://tiktok/111") }

      expect(files_in_output).to contain_exactly("#{base_name}.mp4", "#{base_name}.txt")
    end

    it "reads ownership from a JSON sidecar too" do
      downloader(json_sidecar: true).save_video(post("111"), "https://tiktok/111")
      downloader(json_sidecar: true).save_video(post("222"), "https://tiktok/222")

      expect(files_in_output).to include("#{base_name}-222.json")
    end

    it "does not clobber media whose sidecar has been deleted" do
      downloader.save_video(post("111"), "https://tiktok/111")
      File.delete(File.join(output_dir, "#{base_name}.txt"))

      downloader.save_video(post("222"), "https://tiktok/222")

      expect(read_output("#{base_name}.mp4")).to eq("fake-bytes:https://cdn.example/111.mp4")
      expect(files_in_output).to include("#{base_name}-222.mp4")
    end

    it "leaves names alone when the slugs differ" do
      downloader.save_video(post("111"), "https://tiktok/111")
      downloader.save_video(post("222", "A completely different caption about planes."), "https://tiktok/222")

      expect(files_in_output.grep(/-222/)).to be_empty
    end

    it "adds no second ID when the ID is already in the filename" do
      downloader(filename_id: true).save_video(post("111"), "https://tiktok/111")

      expect(files_in_output).to contain_exactly("#{base_name}-111.mp4", "#{base_name}-111.txt")
    end

    context "with photo sets" do
      it "disambiguates the whole set on one decision" do
        downloader.save_images(post("111"), ["https://cdn/a.jpg", "https://cdn/b.jpg"], "https://tiktok/111")
        downloader.save_images(post("222"), ["https://cdn/c.jpg"], "https://tiktok/222")

        expect(files_in_output).to contain_exactly(
          "#{base_name}-01.jpg", "#{base_name}-02.jpg", "#{base_name}.txt",
          "#{base_name}-222-01.jpg", "#{base_name}-222.txt"
        )
      end

      it "writes one sidecar per set, not per image" do
        downloader.save_images(post("111"), ["https://cdn/a.jpg", "https://cdn/b.jpg"], "https://tiktok/111")

        expect(files_in_output.grep(/\.txt\z/).size).to eq(1)
      end
    end
  end

  describe "audio credit" do
    let(:offline_downloader) do
      Class.new(described_class) do
        private

        def write_binary(url, path, *_args, **_kwargs)
          File.write(path, "fake-bytes:#{url}")
        end
      end
    end

    let(:audio) do
      Subetha::Tiktok::Audio.from({ "id" => "7530081457067920142", "title" => "original sound",
                               "authorName" => "aubory bugg", "original" => true }, "C. Sexton")
    end

    it "adds the sound to the text sidecar" do
      offline_downloader.new(config).save_video(post("111").merge(audio: audio), "https://tiktok/111")

      expect(read_output("#{base_name}.txt")).to include(
        "Audio:       original sound - aubory bugg\n",
        "Audio URL:   https://www.tiktok.com/music/original-sound-7530081457067920142\n"
      )
    end

    it "adds the sound to the JSON sidecar" do
      offline_downloader.new(config(json_sidecar: true))
                        .save_video(post("111").merge(audio: audio), "https://tiktok/111")

      json = JSON.parse(read_output("#{base_name}.json"))
      expect(json["audio"]).to include("artist" => "aubory bugg", "own" => false)
    end

    it "leaves the line out when the post has no sound" do
      offline_downloader.new(config).save_video(post("111"), "https://tiktok/111")

      expect(read_output("#{base_name}.txt")).not_to include("Audio")
    end
  end

  describe "atomic writes" do
    # Fails partway through the body for any URL containing "boom".
    let(:flaky_downloader) do
      Class.new(described_class) do
        private

        def stream_to(url, path, _referer, cookies: nil, redirect_count: 0)
          File.open(path, "wb") do |f|
            f.write("first-half")
            raise IOError, "connection reset" if url.include?("boom")

            f.write("-second-half")
          end
        end
      end
    end

    let(:downloader) { flaky_downloader.new(config) }
    let(:target)     { File.join(output_dir, "clip.mp4") }

    it "renames the completed download into place" do
      downloader.send(:write_binary, "https://cdn/ok.mp4", target, "ref")

      expect(File.read(target)).to eq("first-half-second-half")
    end

    it "leaves no .part file behind on success" do
      downloader.send(:write_binary, "https://cdn/ok.mp4", target, "ref")

      expect(File.exist?("#{target}.part")).to be(false)
    end

    it "writes no final file when the download fails" do
      expect { downloader.send(:write_binary, "https://cdn/boom.mp4", target, "ref") }
        .to raise_error(IOError)

      expect(File.exist?(target)).to be(false)
    end

    it "cleans up the partial file when the download fails" do
      expect { downloader.send(:write_binary, "https://cdn/boom.mp4", target, "ref") }
        .to raise_error(IOError)

      expect(files_in_output).to be_empty
    end

    it "keeps an existing good file when a re-download fails" do
      File.write(target, "previously-archived")

      expect { downloader.send(:write_binary, "https://cdn/boom.mp4", target, "ref") }
        .to raise_error(IOError)

      expect(File.read(target)).to eq("previously-archived")
    end
  end
end
