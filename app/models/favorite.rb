class Favorite < ApplicationRecord
  class Error < Exception ; end

  belongs_to :post
  belongs_to :user
  scope :for_user, ->(user_id) {where("user_id % 100 = #{user_id.to_i % 100} and user_id = #{user_id.to_i}")}

  def self.add(post:, user:)
    Favorite.transaction do
      User.where(id: user.id).select("id").lock("FOR UPDATE").first

      if user.favorite_count >= user.favorite_limit
        raise Error, "You can only keep up to #{user.favorite_limit} favorites. Upgrade your account to save more."
      elsif Favorite.for_user(user.id).where(:user_id => user.id, :post_id => post.id).exists?
        raise Error, "You have already favorited this post"
      end

      Favorite.create!(:user_id => user.id, :post_id => post.id)
      Post.where(:id => post.id).update_all("fav_count = fav_count + 1")
      post.append_user_to_fav_string(user.id)
      User.where(:id => user.id).update_all("favorite_count = favorite_count + 1")
      user.favorite_count += 1
    end
  end

  def self.remove(user:, post: nil, post_id: nil)
    Favorite.transaction do
      if post && post_id.nil?
        post_id = post.id
      end

      User.where(id: user.id).select("id").lock("FOR UPDATE").first

      return unless Favorite.for_user(user.id).where(:user_id => user.id, :post_id => post_id).exists?
      Favorite.for_user(user.id).where(post_id: post_id).delete_all
      Post.where(:id => post_id).update_all("fav_count = fav_count - 1")
      post.delete_user_from_fav_string(user.id) if post
      User.where(:id => user.id).update_all("favorite_count = favorite_count - 1")
      user.favorite_count -= 1
      post.fav_count -= 1 if post
    end
  end
end
