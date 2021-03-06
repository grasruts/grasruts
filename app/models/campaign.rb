# frozen_string_literal: true

class Campaign < ApplicationRecord
  include Discard::Model
  include PgSearch

  enum mode: %i[aon flexible]
  enum status: %i[draft pending online rejected success fail]

  has_many :rewards, dependent: :destroy
  has_many :campaign_updates, dependent: :destroy
  has_many :faqs, dependent: :destroy
  has_many :contributions

  has_attached_file :card_image, styles: { medium: '370x240>', thumb: '100x100>' }, convert_options: {
    thumb: '-quality 75 -strip'
  }
  validates_attachment_content_type :card_image, content_type: /\Aimage\/.*\z/

  belongs_to :user, optional: true
  belongs_to :campaign_category

  validates :name, presence: { message: 'Campaign Name can not be empty' }, on: :create
  validates :campaign_category, presence: { message: 'Category can not be empty' }, on: :create

  validates :name, presence: { message: 'Campaign Name can not be empty' }, on: :basic
  validates :campaign_category, presence: { message: 'Category can not be empty' }, on: :basic
  validates :location, presence: { message: 'Location can not be empty' }, on: :basic
  validates :uri, uniqueness: { message: 'Project URL already taken' }, on: :basic
  validates :uri, presence: { message: 'Project URL cant be empty', on: :basic }

  validates :goal, numericality: { only_integer: true, message: 'Goal must be a number' }, presence: { message: 'Goal must not be empty' }, on: :financing
  validates :deadline, numericality: { less_than_or_equal_to: 365, only_integer: true, message: 'Collection Period must be a number and less than 365 days' }, presence: { message: 'Collection Period can not be empty' }, on: :financing

  validates :about, presence: { message: 'Description is required' }, on: :description

  validates :card_description, length: { maximum: 120, message: 'Card description should not exceed more than 40 words' }, presence: { message: 'Card description is required' }, on: :project_card
  validates :card_image, attachment_presence: { message: 'Card image is required' }, on: :project_card
  validates_with AttachmentPresenceValidator, attributes: :card_image, on: :project_card
  validates_with AttachmentSizeValidator, attributes: :card_image, less_than: 1.megabytes, on: :project_card

  # validates :user, presence: {message:'KYC cant be empty'}, on: :publish
  # validates_associated :user, on: :publish
  validates :rewards, presence: { message: 'Rewards cant be empty' }, on: :publish

  after_update :save_video_id, if: :video_changed?

  pg_search_scope :search_by_campaign, against: %i[name uri], using: {
    tsearch: { any_word: true }
  }

  def self.published_campaigns
    Campaign.includes(:campaign_category, :user).where(status: %w[online success fail]).order(created_at: :desc)
  end

  def self.online_campaigns
    Campaign.includes(:campaign_category, :user).where(status: 'online').limit(4).order(created_at: :desc)
  end

  def publish
    self.status = Campaign.statuses[:online]
    self.published_date = Time.now
    self.save(context: %i[basic financing description project_card publish])
  end

  private

  def save_video_id
    VideoInfoExtractorWorker.perform_async(id)
  end
end
