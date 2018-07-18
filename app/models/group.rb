class Group
  include Mongoid::Document
  field :gid, type: String
  field :name, type: String
  field :is_private, type: Boolean
  field :last_fetched_at, type: DateTime
  has_and_belongs_to_many :users
  has_and_belongs_to_many :summaries
  index({ gid: 1 }, {})
  index({ name: 1 }, {})

  def self.find_or_fetch(client, gid)
    group = self.where(gid: gid).first
    if group
      group.fetch(client) unless (group.last_fetched_at && group.last_fetched_at > 24.hours.ago)
      group
    else
      self.fetch(client, gid)
    end
  end

  def self.fetch(client, gid)
    channel = Rails.cache.fetch("channels##{gid}", expires_in: 1.hours) do
      hit = nil
      channels = client.channels_list()['channels']
      channels.each do |ch|
        if ch['id']==gid
          hit = ch
        end
        Rails.cache.write("channels##{ch['id']}", ch)
      end
      hit
    end
    group = Rails.cache.fetch("groups##{gid}", expires_in: 1.hours) do
      hit = nil
      groups = client.groups_list()['groups']
      groups.each do |gr|
        if gr['id']==gid
          hit = gr
        end
        Rails.cache.write("groups##{gr['id']}", gr)
      end
      hit
    end

    if !channel.nil?
      raw = channel
      is_private = false
    elsif !group.nil?
      raw = group
      is_private = true
    else
      return nil
    end

    new_group = Group.create(
      gid: raw['id'],
      name: raw['name'],
      is_private: is_private,
      last_fetched_at: Time.now,
    )
    raw['members'].each do |member|
      new_group.users << User.where(uid: member)
    end
    new_group.save
  end

  def fetch(client)
    channel = Rails.cache.fetch("channels##{gid}", expires_in: 1.hours) do
      hit = nil
      channels = client.channels_list()['channels']
      channels.each do |ch|
        if ch['id']==gid
          hit = ch
        end
        Rails.cache.write("channels##{ch['id']}", ch)
      end
      hit
    end
    group = Rails.cache.fetch("groups##{gid}", expires_in: 1.hours) do
      hit = nil
      groups = client.groups_list()['groups']
      groups.each do |gr|
        if gr['id']==gid
          hit = gr
        end
        Rails.cache.write("groups##{gr['id']}", gr)
      end
      hit
    end

    if !channel.nil?
      raw = channel
      is_private = false
    elsif !group.nil?
      raw = group
      is_private = true
    else
      return
    end

    self.update(
      name: raw['name'],
      last_fetched_at: Time.now,
    )
    raw['members'].each do |member|
      self.users << User.where(uid: member)
    end
    self.save
  end
end